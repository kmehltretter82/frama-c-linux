/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Frama-C Globals
// --------------------------------------------------------------------------

import React from 'react';
import InfiniteScroll from 'react-infinite-scroller';

import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import { classes } from 'dome/misc/utils';
import { alpha } from 'dome/data/compare';
import { Section, Item, SidebarTitle } from 'dome/frame/sidebars';
import {
  Button, ItemProps, Multiselect, MultiselectItem, MultiselectItemProps
} from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import * as Toolbar from 'dome/frame/toolbars';
import { Hbox } from 'dome/layout/boxes';
import { Dropdown } from 'dome/dialogs';
import { Icon } from 'dome/controls/icons';

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
interface MenuItemProps {
  label: string,
  state: setting,
  title?: string,
  enabled?: boolean
}

export function menuItem(props: MenuItemProps): ItemProps {
  const { label, state, title, enabled = true } = props;
  const [b, flip] = state;
  return {
    label: label,
    enabled: enabled,
    title: title || '',
    checked: b,
    onClick: flip,
  };
}

// --------------------------------------------------------------------------
// --- Lists
// --------------------------------------------------------------------------

interface ScrollableParent {
  scrollableParent: React.RefObject<HTMLDivElement>;
}

type InfiniteScrollListProps = {
  children: JSX.Element[];
} & ScrollableParent

type ListProps = {
  name: string;
  total: number;
  filteringMenuItems?: Dome.PopupMenuItem[];
  filteringMenu?: React.JSX.Element;
  children: JSX.Element[];
} & InfiniteScrollListProps


function InfiniteScrollList(props: InfiniteScrollListProps): JSX.Element {
  const [displayedCount, setDisplayedCount] = React.useState(100);
  const { children, scrollableParent } = props;
  const count = children.length;
  return (
    <InfiniteScroll
      pageStart={0}
      loadMore={() => setDisplayedCount(displayedCount + 100)}
      hasMore={displayedCount < count}
      loader={<Label key={-1}>Loading more...</Label>}
      useWindow={false}
      getScrollParent={() => scrollableParent.current}
    >
      {children.slice(0, displayedCount)}
    </InfiniteScroll>
  );

}

function List(props: ListProps): JSX.Element {
  const { name, total, filteringMenuItems, filteringMenu,
    children, scrollableParent } = props;
  const Name = name.charAt(0).toUpperCase() + name.slice(1);
  const count = children.length;

  const filterButtonProps = {
    icon: 'FILTER',
    title: `${Name}s filtering options (${count} / ${total})`,
    onClick: () => filteringMenuItems && Dome.popupMenu(filteringMenuItems),
  };

  let contents;

  if (count <= 0 && total > 0) {
    const button = <Button {...filterButtonProps}
      label={`${Name}s filters`} />;
    contents =
      <div className='dome-xSideBarSection-content'>
        <label className='globals-info'>
          All {name}s are filtered. Try adjusting {name} filters.
        </label>
        { filteringMenu
            ? <Dropdown control={button}>{filteringMenu}</Dropdown>
            : button
        }
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
      <InfiniteScrollList scrollableParent={scrollableParent}>
        {children}
      </InfiniteScrollList>;
  }

  return (
    <Section
      label={`${Name}s`}
      title={`${Name}s ${count} / ${total}`}
      defaultUnfold
      settings={`frama-c.sidebar.${name}s`}
      rightButtonProps={filterButtonProps}
      filteringMenu={filteringMenu}
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
  fct: functionsData,
  scope: States.Scope,
  icon?: string
}

function FctItem(props: FctItemProps): JSX.Element {
  const { fct, scope, icon } = props;
  const { name, signature, main, stdlib, builtin, defined, decl } = fct;
  const { scopes, label: selectionLabel } = Locations.useSelection();
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
      key={decl}
      icon={icon}
      className={className}
      label={name}
      title={signature}
      selected={decl === scope}
      onSelection={() => States.setCurrentScope(decl)}
    >
      {attributes && <span className="globals-attr">{attributes}</span>}
      {scopes && scopes.includes(decl) &&
         <Icon id='MULTICHECK' kind='selected'
          title={'Selected in the Locations panel: ' + selectionLabel} />
      }
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

interface FunctionFilterRet {
  contextFctFilter: React.JSX.Element,
  multipleSelection: States.Scope[],
  showFunction: (fct: functionsData) => boolean,
  isSelected: (fct: functionsData) => boolean
}

export function useFunctionFilter(): FunctionFilterRet {
  const { scopes } = Locations.useSelection();
  const multipleSelection = React.useMemo(() => scopes || [], [scopes]);
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

  const contextFctMenuItems: MultiselectItemProps[] = [
    menuItem({ label: 'Show Frama-C builtins', state: builtinState }),
    menuItem({ label: 'Show stdlib functions', state: stdlibState }),
    'separator',
    menuItem({ label: 'Show defined functions', state: defState }),
    menuItem({ label: 'Show undefined functions', state: undefState }),
    'separator',
    menuItem({ label: 'Show non-extern functions', state: internState }),
    menuItem({ label: 'Show extern functions', state: externState }),
    'separator',
    menuItem({ label: 'Show functions analyzed by Eva',
              state: evaAnalyzedState, enabled: evaComputed }),
    menuItem({ label: 'Show functions unreached by Eva',
              state: evaUnreachedState, enabled: evaComputed }),
    'separator',
    menuItem({ label: 'Selected only', state: selectedState,
              title: 'Show only the functions selected in the Locations panel',
              enabled: multipleSelectionActive }),
  ];

  const itemsComp = contextFctMenuItems.map(
    (e, i) => <MultiselectItem key={i} item={e} />);
  const contextFctFilter = <Multiselect>{ itemsComp }</Multiselect>;

  return { contextFctFilter, multipleSelection, showFunction, isSelected };
}

export function Functions(props: ScrollableParent): JSX.Element {
  // Hooks
  const scope = States.useCurrentScope();

  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const fcts = React.useMemo(() => computeFcts(ker, eva), [ker, eva]);
  const { showFunction, contextFctFilter } = useFunctionFilter();

  // Filtered
  const items =
    fcts
      .filter(showFunction)
      .sort((f, g) => alpha(f.name, g.name))
      .map((fct) => <FctItem key={fct.decl} fct={fct} scope={scope}/>);

  return (
    <List
      name="function"
      total={fcts.length}
      filteringMenu={contextFctFilter}
      scrollableParent={props.scrollableParent}
    >
      {items}
    </List>
  );
}

// --------------------------------------------------------------------------
// --- Global variables section
// --------------------------------------------------------------------------

interface VarItemProps {
  variable: Ast.globalsData,
  scope: States.Scope,
  icon?: string
}

function VarItem(props: VarItemProps): JSX.Element {
  const { variable, scope, icon } = props;
  const { name, type, decl } = variable;
  const varMarker = React.useMemo(
    () => States.getDeclaration(decl).self, [decl]);
  const { markers, label: selectionLabel } = Locations.useSelection();
  return (
    <Item
      key={decl}
      icon={icon}
      label={name}
      title={type}
      selected={decl === scope}
      onSelection={() => States.setCurrentScope(decl)}
    >
      {markers && markers.includes(varMarker) &&
         <Icon id='MULTICHECK' kind='selected'
          title={'Selected in the Locations panel: ' + selectionLabel} />
      }
    </Item>
  );
}

interface VariablesFilterRet {
  contextVarFilter: React.JSX.Element,
  showVariable: (vi: Ast.globalsData) => boolean,
}

export function useVariableFilter(): VariablesFilterRet {
  // Filter settings
  function useFlipSettings(label: string, b: boolean): setting {
    return Dome.useFlipSettings('ivette.globals.' + label, b);
  }
  const stdlibState = useFlipSettings('stdlib', false);
  const externState = useFlipSettings('extern', true);
  const nonExternState = useFlipSettings('non-extern', true);
  const isConstState = useFlipSettings('const', true);
  const nonConstState = useFlipSettings('non-const', true);
  const volatileState = useFlipSettings('volatile', true);
  const nonVolatileState = useFlipSettings('non-volatile', true);
  const ghostState = useFlipSettings('ghost', true);
  const nonGhostState = useFlipSettings('non-ghost', true);
  const initState = useFlipSettings('init', true);
  const nonInitState = useFlipSettings('non-init', true);
  const sourceState = useFlipSettings('source', true);
  const nonSourceState = useFlipSettings('non-source', false);

  const [stdlib, ] = stdlibState;
  const [extern, ] = externState;
  const [nonExtern, ] = nonExternState;
  const [isConst, ] = isConstState;
  const [nonConst, ] = nonConstState;
  const [volatile, ] = volatileState;
  const [nonVolatile, ] = nonVolatileState;
  const [ghost, ] = ghostState;
  const [nonGhost, ] = nonGhostState;
  const [init, ] = initState;
  const [nonInit, ] = nonInitState;
  const [source, ] = sourceState;
  const [nonSource, ] = nonSourceState;

  const showVariable = React.useMemo(() => {
    return (vi: Ast.globalsData): boolean => {
      const visible =
        /* Never show global variables representing string literals.
           If needed, add a new filter to show these variables. */
        !vi.stringLiteral
        && (stdlib || !vi.stdlib)
        && (extern || !vi.extern) && (nonExtern || vi.extern)
        && (isConst || !vi.const) && (nonConst || vi.const)
        && (volatile || !vi.volatile) && (nonVolatile || vi.volatile)
        && (ghost || !vi.ghost) && (nonGhost || vi.ghost)
        && (init || !vi.init) && (nonInit || vi.init)
        && (source || !vi.source) && (nonSource || vi.source);
      return !!visible;
    };
  }, [stdlib, extern, nonExtern, isConst,
      nonConst, volatile, nonVolatile, ghost,
      nonGhost, init, nonInit, source, nonSource
  ]);

  // Context menu to change filter settings
  /* eslint-disable max-len */
  const contextVarMenuItems: MultiselectItemProps[] = [
    menuItem({ label: 'Show stdlib variables', state: stdlibState }),
    'separator',
    menuItem({ label: 'Show extern variables', state: externState }),
    menuItem({ label: 'Show non-extern variables', state: nonExternState }),
    'separator',
    menuItem({ label: 'Show const variables', state: isConstState }),
    menuItem({ label: 'Show non-const variables', state: nonConstState }),
    'separator',
    menuItem({ label: 'Show volatile variables', state: volatileState }),
    menuItem({ label: 'Show non-volatile variables', state: nonVolatileState }),
    'separator',
    menuItem({ label: 'Show ghost variables', state: ghostState }),
    menuItem({ label: 'Show non-ghost variables', state: nonGhostState }),
    'separator',
    menuItem({ label: 'Show variables with explicit initializer', state: initState }),
    menuItem({ label: 'Show variables without explicit initializer', state: nonInitState }),
    'separator',
    menuItem({ label: 'Show variables from the source code', state: sourceState }),
    menuItem({ label: 'Show variables generated from analyses', state: nonSourceState }),
  ];
  /* eslint-enable max-len */

  const itemsComp = contextVarMenuItems.map(
    (e, i) => <MultiselectItem key={i} item={e} />);
  const contextVarFilter =  <Multiselect>{ itemsComp }</Multiselect>;

  return { contextVarFilter, showVariable };
}

export function Variables(props: ScrollableParent): JSX.Element {
  // Hooks
  const scope = States.useCurrentScope();
  const variables = States.useSyncArrayData(Ast.globals);
  const { showVariable, contextVarFilter } = useVariableFilter();

  // Filtered
  const items =
    variables
      .filter(showVariable)
      .sort((v1, v2) => alpha(v1.name, v2.name))
      .map((v) => <VarItem key={v.decl} scope={scope} variable={v}/>);

  return (
    <List
      name="variable"
      total={variables.length}
      filteringMenu={contextVarFilter}
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
// --- Global Annotations Section
// --------------------------------------------------------------------------

export function GlobalAnnots(): JSX.Element {
  return <>
    <Declarations
      id='ltypes'
      label='Logic Types'
      title='Logic Types'
      filter={(d): boolean => d.kind === 'LTYPE'}
    />
    <Declarations
      id='lfun-preds'
      label='Predicates and Logic Functions'
      title='Predicates and Logic Functions'
      filter={(d): boolean => d.kind === 'LFUNPRED'}
    />
    <Declarations
      id='laxiomatics'
      label='Axiomatic Definitions'
      title='Axiomatic Definitions'
      filter={(d): boolean => d.kind === 'AXIOMATIC'}
    />
    <Declarations
      id='lemmas'
      label='Lemmas'
      title='Lemmas'
      filter={(d): boolean => d.kind === 'LEMMA'}
    />
    <Declarations
      id='lmodules'
      label='Logic Modules'
      title='Logic Modules'
      filter={(d): boolean => d.kind === 'MODULE'}
    />
    <Declarations
      id='linvariants'
      label='Invariants'
      title='Invariants'
      filter={(d): boolean => d.kind === 'INVARIANT'}
    />
    <Declarations
      id='lmodel'
      label='Model Fields'
      title='Model Fields'
      filter={(d): boolean => d.kind === 'MODEL'}
    />
    <Declarations
      id='lvolatile'
      label='Volatile Annotations'
      title='Volatile Annotations'
      filter={(d): boolean => d.kind === 'VOLATILE'}
    />
    <Declarations
      id='lextensions'
      label='ACSL Extensions'
      title='ACSL Extensions'
      filter={(d): boolean => d.kind === 'EXTENSION'}
    />
  </>;
}

// --------------------------------------------------------------------------
// --- Files Section
// --------------------------------------------------------------------------

type FilesProps = {
  showFunction: (fct: functionsData) => boolean;
  showFctsState: [boolean, () => void];
  showVariable: (vi: Ast.globalsData) => boolean
  showVarsState: [boolean, () => void];
} & ScrollableParent

export function Files(props: FilesProps): JSX.Element {
  const { showFunction, showFctsState, showVariable, showVarsState,
    scrollableParent } = props;
  // Hooks
  const scope = States.useCurrentScope();
  const getDecl = States.useSyncArrayGetter(Ast.declAttributes);
  const currentSection = React.useMemo(() => {
    return getDecl(scope)?.source.file;
  }, [scope, getDecl]);

  // functions
  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const fcts = React.useMemo(() => computeFcts(ker, eva), [ker, eva]);
  const [showFcts, ] = showFctsState;

  // Variables
  const variables = States.useSyncArrayData(Ast.globals);
  const [showVars, ] = showVarsState;

  interface InfosFile {
    label: string,
    fcts: functionsData[],
    vars: Ast.globalsData[]
  }

  type InfosFileList = {[key: string]: InfosFile };
  const files = React.useMemo(() => {
    const newFiles: InfosFileList = {};

    function createFileIfNeeded(loc: Ast.source): void {
      if (!newFiles[loc.file])
        newFiles[loc.file] = { label: loc.base, fcts: [], vars: [] };
    }

    fcts.filter(showFunction)
    .sort((f, g) => alpha(f.name, g.name))
    .forEach((fct) => {
      createFileIfNeeded(fct.sloc);
      newFiles[fct.sloc.file].fcts.push(fct);
    });

    variables.filter(showVariable)
      .sort((v1, v2) => alpha(v1.name, v2.name))
      .forEach((elt) => {
        createFileIfNeeded(elt.sloc);
        newFiles[elt.sloc.file].vars.push(elt);
      });

    return newFiles;
  }, [fcts, showFunction, variables, showVariable]);

  function getList([path, infos]: [string, InfosFile]): JSX.Element | null {
    const { label, fcts, vars } = infos;
    const fctsComp: JSX.Element[] = showFcts ?
      fcts.map(fct =>
        <FctItem key={fct.decl} fct={fct} scope={scope} icon='FUNCTION'/>)
      : [];
    const varsComp: JSX.Element[] = showVars ? vars.map((v) =>
      <VarItem key={v.decl} scope={scope} variable={v} icon='VARIABLE'/>) : [];
    const items = fctsComp.concat(varsComp);
    if(items.length === 0) return null;

    return (
      <Section
        key={path}
        label={label}
        title={path}
        infos={currentSection === path ? '(active)' : undefined}
        className='globals-section'
      >
        <InfiniteScrollList scrollableParent={scrollableParent} >
          {items}
        </InfiniteScrollList>
      </Section>
    );
  }

  return <>
    {
      Object.entries(files)
        .sort((v1, v2) => alpha(v1[1].label, v2[1].label))
        .map(elt => getList(elt))
    }
  </>;
}

interface SidebarFilesTitleProps {
  showFctsState: [boolean, () => void];
  contextFctFilter: React.JSX.Element;
  showVarsState: [boolean, () => void];
  contextVarFilter: React.JSX.Element;
}

function SidebarFilesTitle(props: SidebarFilesTitleProps): JSX.Element {
  const { showFctsState, contextFctFilter,
          showVarsState, contextVarFilter } = props;
  const [showFcts, flipShowFcts] = showFctsState;
  const [showVars, flipShowVars] = showVarsState;

  return (
    <SidebarTitle label='Files'>
      <Hbox>
        <Toolbar.ButtonGroup>
          <Toolbar.Button
            icon="FUNCTION"
            title={'Show functions'}
            selected={showFcts}
            onClick={() => flipShowFcts()}
            />
          <Dropdown control={ <Toolbar.Button icon='FILTER' /> }
          >{contextFctFilter}</Dropdown>
        </Toolbar.ButtonGroup>
        <Toolbar.ButtonGroup>
          <Toolbar.Button
            icon="VARIABLE"
            title={'Show variables'}
            selected={showVars}
            onClick={() => flipShowVars()}
            />
          <Dropdown control={ <Toolbar.Button icon='FILTER' /> }
          >{contextVarFilter}</Dropdown>
        </Toolbar.ButtonGroup>
      </Hbox>
    </SidebarTitle>
  );
}

// --------------------------------------------------------------------------
// --- All globals
// --------------------------------------------------------------------------

export function GlobalByFiles(): JSX.Element {
  const scrollableArea = React.useRef<HTMLDivElement>(null);

  // functions
  const { showFunction, contextFctFilter } = useFunctionFilter();
  const showFctsState =
    Dome.useFlipSettings('ivette.files.show.functions', true);

  // Variables
  const { showVariable, contextVarFilter } = useVariableFilter();
  const showVarsState =
    Dome.useFlipSettings('ivette.files.show.globals', true);

  return (<>
      <SidebarFilesTitle
        showFctsState={showFctsState}
        contextFctFilter={contextFctFilter}
        showVarsState={showVarsState}
        contextVarFilter={contextVarFilter}
      />
      <div ref={scrollableArea} className="globals-scrollable-area">
        <Files scrollableParent={scrollableArea}
          showFctsState={showFctsState}
          showFunction={showFunction}
          showVarsState={showVarsState}
          showVariable={showVariable}
        />
      </div>
    </>
  );
}

export function GlobalDeclarations(): JSX.Element {
  const scrollableArea = React.useRef<HTMLDivElement>(null);
  return (<>
      <SidebarTitle label='Global Declarations' />
      <div ref={scrollableArea} className="globals-scrollable-area">
        <Types />
        <Variables scrollableParent={scrollableArea} />
        <Functions scrollableParent={scrollableArea} />
        <GlobalAnnots />
      </div>
    </>
  );
}
