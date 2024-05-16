/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Frama-C Globals
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import { classes } from 'dome/misc/utils';
import { alpha } from 'dome/data/compare';
import { Section, Item } from 'dome/frame/sidebars';
import { Button } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import InfiniteScroll from 'react-infinite-scroller';

import * as Ivette from 'ivette';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Locations from 'frama-c/kernel/Locations';
import { computationState } from 'frama-c/plugins/eva/api/general';
import * as Eva from 'frama-c/plugins/eva/api/general';


// --------------------------------------------------------------------------
// --- Global Search Hints
// --------------------------------------------------------------------------

function globalHints(): Ivette.Hint[] {
  const globals = States.getSyncArray(Ast.declAttributes).getArray();
  return globals.map((g: Ast.declAttributesData) => ({
    id: g.decl,
    name: g.name,
    label: g.label,
    onClick: () => States.setCurrentScope(g.decl),
  }));
}

const globalMode: Ivette.SearchProps = {
  id: 'frama-c.kernel.globals',
  label: 'Globals',
  title: 'Lookup for Global Declarations',
  placeholder: 'declaration',
  hints: globalHints,
};

function resetMode(enabled: boolean): void {
  Ivette.updateSearchMode({ id: globalMode.id, enabled });
  Ivette.selectSearchMode(globalMode.id);
}

{
  Ivette.registerSearchMode(globalMode);
  Dome.find.on(() => Ivette.focusSearchMode(globalMode.id));
  Server.onReady(() => resetMode(true));
  Server.onShutdown(() => resetMode(false));
  resetMode(false);
}

// --------------------------------------------------------------------------
// --- Menu item
// --------------------------------------------------------------------------

type setting = [boolean, () => void]
function menuItem(label: string, [b, flip]: setting, enabled?: boolean)
  : Dome.PopupMenuItem {
  return {
    label: label,
    enabled: enabled !== undefined ? enabled : true,
    checked: b,
    onClick: flip,
  };
}

// --------------------------------------------------------------------------
// --- Lists
// --------------------------------------------------------------------------

interface InfiniteScrollableListProps {
  scrollableParent: React.RefObject<HTMLDivElement>;
}

type ListProps = {
  name: string;
  total: number;
  filteringMenuItems: Dome.PopupMenuItem[];
  children: JSX.Element[];
} & InfiniteScrollableListProps

function List(props: ListProps): JSX.Element {
  const [displayedCount, setDisplayedCount] = React.useState(100);
  const { name, total, filteringMenuItems, children, scrollableParent } = props;
  const Name = name.charAt(0).toUpperCase() + name.slice(1);
  const count = children.length;

  const filterButtonProps = {
    icon: 'TUNINGS',
    title: `${Name}s filtering options (${count} / ${total})`,
    onClick: () => Dome.popupMenu(filteringMenuItems),
  };

  let contents;

  if (count <= 0 && total > 0) {
    contents =
      <div className='dome-xSideBarSection-content'>
        <label className='globals-info'>
          All {name}s are filtered. Try adjusting {name} filters.
        </label>
        <Button {...filterButtonProps} label={`${Name}s filters`} />
      </div>;
  }
  else if (total <= 0) {
    contents =
      <div className='dome-xSideBarSection-content'>
        <label className='globals-info'>
          There is no {name} to display.
        </label>
      </div>;
  }
  else {
    contents =
      // @ts-expect-error (incompatibility due to @types/react versions)
      <InfiniteScroll
        pageStart={0}
        loadMore={() => setDisplayedCount(displayedCount + 100)}
        hasMore={displayedCount < count}
        loader={<Label key={-1}>Loading more...</Label>}
        useWindow={false}
        getScrollParent={() => scrollableParent.current}
      >
        {children.slice(0, displayedCount)}
      </InfiniteScroll>;
  }

  return (
    <Section
      label={`${Name}s`}
      title={`${Name}s ${count} / ${total}`}
      defaultUnfold
      settings={`frama-c.sidebar.${name}s`}
      rightButtonProps={filterButtonProps}
      summary={[count]}
      className='globals-section'
    >
      {contents}
    </Section>
  );
}


// --------------------------------------------------------------------------
// --- Function items
// --------------------------------------------------------------------------

interface FctItemProps {
  fct: functionsData;
  current: string | undefined;
}

function FctItem(props: FctItemProps): JSX.Element {
  const { name, signature, main, stdlib, builtin, defined, decl } = props.fct;
  const className = classes(
    main && 'globals-main',
    (stdlib || builtin) && 'globals-stdlib',
  );
  const attributes = classes(
    main && '(main)',
    !stdlib && !builtin && !defined && '(ext)',
  );
  return (
    <Item
      className={className}
      label={name}
      title={signature}
      selected={name === props.current}
      onSelection={() => States.setCurrentScope(decl)}
    >
      {attributes && <span className="globals-attr">{attributes}</span>}
    </Item>
  );
}

// --------------------------------------------------------------------------
// --- Functions Section
// --------------------------------------------------------------------------

type functionsData =
  Ast.functionsData | (Ast.functionsData & Eva.functionsData);

type FctKey = Json.key<'#functions'>;

function computeFcts(
  ker: States.ArrayProxy<FctKey, Ast.functionsData>,
  eva: States.ArrayProxy<FctKey, Eva.functionsData>,
): functionsData[] {
  const arr: functionsData[] = [];
  ker.forEach((kf) => {
    const ef = eva.getData(kf.key);
    arr.push({ ...ef, ...kf });
  });
  return arr.sort((f, g) => alpha(f.name, g.name));
}

type FunctionProps = InfiniteScrollableListProps

export function Functions(props: FunctionProps): JSX.Element {

  // Hooks
  const scope = States.useCurrentScope();
  const { kind, name } = States.useDeclaration(scope);
  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const getMarker = States.useSyncArrayGetter(Ast.markerAttributes);
  const fcts = React.useMemo(() => computeFcts(ker, eva), [ker, eva]);

  function useFlipSettings(label: string, b: boolean): setting {
    return Dome.useFlipSettings('ivette.functions.' + label, b);
  }
  const stdlib = useFlipSettings('stdlib', false);
  const builtin = useFlipSettings('builtin', false);
  const def = useFlipSettings('def', true);
  const undef = useFlipSettings('undef', true);
  const intern = useFlipSettings('intern', true);
  const extern = useFlipSettings('extern', true);
  const evaAnalyzed = useFlipSettings('eva-analyzed', true);
  const evaUnreached = useFlipSettings('eva-unreached', true);
  const selected = useFlipSettings('selected', false);

  const { markers } = Locations.useSelection();
  const multipleSelection: States.Scope[] =
    React.useMemo(
      () => markers.map((m) => getMarker(m)?.scope)
      , [getMarker, markers]);
  const multipleSelectionActive = multipleSelection.length > 0;
  const evaComputed = States.useSyncValue(computationState) === 'computed';

  // Currently selected function.
  const current = (scope && kind === 'FUNCTION') ? name : undefined;

  function isSelected(fct: functionsData): boolean {
    const idx = multipleSelection.findIndex((s) => s === fct.decl);
    return 0 <= idx;
  }

  function showFunction(fct: functionsData): boolean {
    const visible =
      (stdlib[0] || !fct.stdlib)
      && (builtin[0] || !fct.builtin)
      && (def[0] || !fct.defined)
      && (undef[0] || fct.defined)
      && (intern[0] || fct.extern)
      && (extern[0] || !fct.extern)
      && (!multipleSelectionActive || !selected[0] || isSelected(fct))
      && (evaAnalyzed[0] || !evaComputed ||
        !('eva_analyzed' in fct && fct.eva_analyzed === true))
      && (evaUnreached[0] || !evaComputed ||
        ('eva_analyzed' in fct && fct.eva_analyzed === true));
    return !!visible;
  }

  const contextMenuItems: Dome.PopupMenuItem[] = [
    menuItem('Show Frama-C builtins', builtin),
    menuItem('Show stdlib functions', stdlib),
    'separator',
    menuItem('Show defined functions', def),
    menuItem('Show undefined functions', undef),
    'separator',
    menuItem('Show non-extern functions', intern),
    menuItem('Show extern functions', extern),
    'separator',
    menuItem('Show functions analyzed by Eva', evaAnalyzed, evaComputed),
    menuItem('Show functions unreached by Eva', evaUnreached, evaComputed),
    'separator',
    menuItem('Selected only', selected, multipleSelectionActive),
  ];

  // Filtered
  const items =
    fcts
      .filter(showFunction)
      .map((fct) => <FctItem key={fct.key} fct={fct} current={current} />);

  return (
    <List
      name="function"
      total={fcts.length}
      filteringMenuItems={contextMenuItems}
      scrollableParent={props.scrollableParent}
    >
      {items}
    </List>
  );
}

// --------------------------------------------------------------------------
// --- Global variables section
// --------------------------------------------------------------------------

function makeVarItem(
  scope: States.Scope,
  props: Ast.globalsData,
): JSX.Element {
  const { name, type, decl } = props;
  return (
    <Item
      key={decl}
      label={name}
      title={type}
      selected={decl === scope}
      onSelection={() => States.setCurrentScope(decl)}
    />
  );
}

type VariablesProps = InfiniteScrollableListProps

export function Variables(props: VariablesProps): JSX.Element {

  // Hooks
  const scope = States.useCurrentScope();
  const variables = States.useSyncArrayData(Ast.globals);

  // Filter settings
  function useFlipSettings(label: string, b: boolean): setting {
    return Dome.useFlipSettings('ivette.globals.' + label, b);
  }
  const stdlib = useFlipSettings('stdlib', false);
  const extern = useFlipSettings('extern', true);
  const nonExtern = useFlipSettings('non-extern', true);
  const isConst = useFlipSettings('const', true);
  const nonConst = useFlipSettings('non-const', true);
  const volatile = useFlipSettings('volatile', true);
  const nonVolatile = useFlipSettings('non-volatile', true);
  const ghost = useFlipSettings('ghost', true);
  const nonGhost = useFlipSettings('non-ghost', true);
  const init = useFlipSettings('init', true);
  const nonInit = useFlipSettings('non-init', true);
  const source = useFlipSettings('source', true);
  const nonSource = useFlipSettings('non-source', false);

  function showVariable(vi: Ast.globalsData): boolean {
    const visible =
      (stdlib[0] || !vi.stdlib)
      && (extern[0] || !vi.extern) && (nonExtern[0] || vi.extern)
      && (isConst[0] || !vi.const) && (nonConst[0] || vi.const)
      && (volatile[0] || !vi.volatile) && (nonVolatile[0] || vi.volatile)
      && (ghost[0] || !vi.ghost) && (nonGhost[0] || vi.ghost)
      && (init[0] || !vi.init) && (nonInit[0] || vi.init)
      && (source[0] || !vi.source) && (nonSource[0] || vi.source);
    return !!visible;
  }

  // Context menu to change filter settings
  const contextMenuItems: Dome.PopupMenuItem[] = [
    menuItem('Show stdlib variables', stdlib),
    'separator',
    menuItem('Show extern variables', extern),
    menuItem('Show non-extern variables', nonExtern),
    'separator',
    menuItem('Show const variables', isConst),
    menuItem('Show non-const variables', nonConst),
    'separator',
    menuItem('Show volatile variables', volatile),
    menuItem('Show non-volatile variables', nonVolatile),
    'separator',
    menuItem('Show ghost variables', ghost),
    menuItem('Show non-ghost variables', nonGhost),
    'separator',
    menuItem('Show variables with explicit initializer', init),
    menuItem('Show variables without explicit initializer', nonInit),
    'separator',
    menuItem('Show variables from the source code', source),
    menuItem('Show variables generated from analyses', nonSource),
  ];

  // Filtered
  const items =
    variables
      .filter(showVariable)
      .map((v) => makeVarItem(scope, v));

  return (
    <List
      name="variable"
      total={variables.length}
      filteringMenuItems={contextMenuItems}
      scrollableParent={props.scrollableParent}
    >
      {items}
    </List>
  );
}


// --------------------------------------------------------------------------
// --- Generic Declaration Section
// --------------------------------------------------------------------------

interface DeclarationsProps {
  id: string;
  label: string;
  title: string;
  filter: (props: Ast.declAttributesData) => boolean;
  defaultUnfold?: boolean;
}

function makeItem(
  scope: States.Scope,
  attributes: Ast.declAttributesData
): JSX.Element {
  const { decl, name, label } = attributes;
  return (
    <Item
      key={decl}
      label={name}
      title={label}
      selected={decl === scope}
      onSelection={() => States.setCurrentScope(decl)}
    />
  );
}

export function Declarations(props: DeclarationsProps): JSX.Element {
  const { id, label, title, filter, defaultUnfold = false } = props;
  const settings = React.useMemo(() => `frama-c.sidebar.${id}`, [id]);
  const data = States.useSyncArrayData(Ast.declAttributes);
  const scope = States.useCurrentScope();
  const items = React.useMemo(
    () =>
      data
        .filter(filter)
        .map((d) => makeItem(scope, d))
    , [scope, data, filter]
  );
  return (
    <Section
      label={label}
      title={title}
      defaultUnfold={defaultUnfold}
      settings={settings}
      summary={[items.length]}
      className='globals-section'
    >
      {items}
    </Section>
  );
}

// --------------------------------------------------------------------------
// --- Types Section
// --------------------------------------------------------------------------

const filterTypes = (d: Ast.declAttributesData): boolean => {
  switch (d.kind) {
    case 'TYPE':
    case 'ENUM':
    case 'UNION':
    case 'STRUCT':
      return true;
    default:
      return false;
  }
};

export function Types(): JSX.Element {
  return (
    <Declarations
      id='types'
      label='Types'
      title='Typedefs, Structs, Unions and Enums'
      filter={filterTypes}
    />
  );
}

// --------------------------------------------------------------------------
// --- All globals
// --------------------------------------------------------------------------

export default function Globals(): JSX.Element {
  const scrollableArea = React.useRef<HTMLDivElement>(null);
  return (
    <div ref={scrollableArea} className="globals-scrollable-area">
      <Types />
      <Variables scrollableParent={scrollableArea} />
      <Functions scrollableParent={scrollableArea} />
    </div>
  );
}

// --------------------------------------------------------------------------
