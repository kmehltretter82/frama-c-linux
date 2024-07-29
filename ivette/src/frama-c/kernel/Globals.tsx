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

export type setting = [boolean, () => void]
export function menuItem(label: string, [b, flip]: setting, enabled?: boolean)
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

export function computeFcts(
  ker: States.ArrayProxy<FctKey, Ast.functionsData>,
  eva: States.ArrayProxy<FctKey, Eva.functionsData>,
): functionsData[] {
  const arr: functionsData[] = [];
  ker.forEach((kf) => {
    const ef = eva.getData(kf.key);
    arr.push({ ...ef, ...kf });
  });
  return arr;
}

type FunctionProps = InfiniteScrollableListProps

interface FunctionFilterRet {
  contextMenuItems: Dome.PopupMenuItem[],
  multipleSelection: States.Scope[],
  showFunction: (fct: functionsData) => boolean,
  isSelected: (fct: functionsData) => boolean
}

export function useFunctionFilter(): FunctionFilterRet {
  const getMarker = States.useSyncArrayGetter(Ast.markerAttributes);
  const { markers } = Locations.useSelection();
  const multipleSelection: States.Scope[] =
    React.useMemo(
      () => markers.map((m) => getMarker(m)?.scope)
      , [getMarker, markers]);
  const multipleSelectionActive = multipleSelection.length > 0;
  const evaComputed = States.useSyncValue(computationState) === 'computed';

  const isSelected = React.useMemo(() => {
    return (fct: functionsData): boolean => {
      const idx = multipleSelection.findIndex((s) => s === fct.decl);
      return 0 <= idx;
    };
  }, [multipleSelection]);

  const useFlipSettings = (label: string, b: boolean): setting => {
    return Dome.useFlipSettings('ivette.functions.' + label, b);
  };

  const stdlibState = useFlipSettings('stdlib', false);
  const builtinState = useFlipSettings('builtin', false);
  const defState = useFlipSettings('def', true);
  const undefState = useFlipSettings('undef', true);
  const internState = useFlipSettings('intern', true);
  const externState = useFlipSettings('extern', true);
  const evaAnalyzedState = useFlipSettings('eva-analyzed', true);
  const evaUnreachedState = useFlipSettings('eva-unreached', true);
  const selectedState = useFlipSettings('selected', false);

  const [stdlib, ] = stdlibState;
  const [builtin, ] = builtinState;
  const [def, ] = defState;
  const [undef, ] = undefState;
  const [intern, ] = internState;
  const [extern, ] = externState;
  const [evaAnalyzed, ] = evaAnalyzedState;
  const [evaUnreached, ] = evaUnreachedState;
  const [selected, ] = selectedState;

  const showFunction = React.useMemo(() => {
    return (fct: functionsData): boolean => {
        const visible =
          (stdlib || !fct.stdlib)
          && (builtin || !fct.builtin)
          && (def || !fct.defined)
          && (undef || fct.defined)
          && (intern || fct.extern)
          && (extern || !fct.extern)
          && (!multipleSelectionActive || !selected || isSelected(fct))
          && (evaAnalyzed || !evaComputed ||
            !('eva_analyzed' in fct && fct.eva_analyzed === true))
          && (evaUnreached || !evaComputed ||
            ('eva_analyzed' in fct && fct.eva_analyzed === true));
        return !!visible;
      };
  }, [stdlib, builtin, def, undef, intern, extern,
    evaAnalyzed, evaUnreached, selected,
    evaComputed, isSelected, multipleSelectionActive
  ]);

  const contextMenuItems: Dome.PopupMenuItem[] = [
    menuItem('Show Frama-C builtins', builtinState),
    menuItem('Show stdlib functions', stdlibState),
    'separator',
    menuItem('Show defined functions', defState),
    menuItem('Show undefined functions', undefState),
    'separator',
    menuItem('Show non-extern functions', internState),
    menuItem('Show extern functions', externState),
    'separator',
    menuItem('Show functions analyzed by Eva', evaAnalyzedState, evaComputed),
    menuItem('Show functions unreached by Eva', evaUnreachedState, evaComputed),
    'separator',
    menuItem('Selected only', selectedState, multipleSelectionActive),
  ];

  return {
    contextMenuItems: contextMenuItems,
    multipleSelection: multipleSelection,
    showFunction: showFunction,
    isSelected: isSelected
  };
}

export function Functions(props: FunctionProps): JSX.Element {
  // Hooks
  const scope = States.useCurrentScope();
  const { kind, name } = States.useDeclaration(scope);

  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const fcts = React.useMemo(() => computeFcts(ker, eva), [ker, eva]);
  const { showFunction, contextMenuItems } = useFunctionFilter();

  // Currently selected function.
  const current = (scope && kind === 'FUNCTION') ? name : undefined;

  // Filtered
  const items =
    fcts
      .filter(showFunction)
      .sort((f, g) => alpha(f.name, g.name))
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
      .sort((v1, v2) => alpha(v1.name, v2.name))
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
        .sort((d1, d2) => alpha(d1.name, d2.name))
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
