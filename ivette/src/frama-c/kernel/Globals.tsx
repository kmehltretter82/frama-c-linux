/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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
  return globals.map((g : Ast.declAttributesData) => ({
    id: g.decl,
    name: g.name,
    label: g.label,
    onClick: () => States.setCurrentScope(g.decl),
  }));
}

const globalMode : Ivette.ModeProps = {
  id: 'frama-c.kernel.globals',
  label: 'Globals',
  title: 'Lookup for Global Declarations',
  placeholder: 'declaration',
  hints: globalHints,
};

function resetMode(enabled: boolean): void {
  Ivette.updateMode({ id: globalMode.id, enabled });
  Ivette.selectMode(globalMode.id);
}

{
  Ivette.registerMode(globalMode);
  Dome.find.on(() => Ivette.focusMode(globalMode.id));
  Server.onReady(() => resetMode(true));
  Server.onShutdown(() => resetMode(false));
  resetMode(false);
}

// --------------------------------------------------------------------------
// --- Function Item
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

export function Functions(): JSX.Element {

  // Hooks
  const scope = States.useCurrentScope();
  const { kind, name } = States.useDeclaration(scope);
  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const getMarker = States.useSyncArrayGetter(Ast.markerAttributes);
  const fcts = React.useMemo(() => computeFcts(ker, eva), [ker, eva]);
  const { useFlipSettings } = Dome;
  const [stdlib, flipStdlib] =
    useFlipSettings('ivette.globals.stdlib', false);
  const [builtin, flipBuiltin] =
    useFlipSettings('ivette.globals.builtin', false);
  const [def, flipDef] =
    useFlipSettings('ivette.globals.def', true);
  const [undef, flipUndef] =
    useFlipSettings('ivette.globals.undef', true);
  const [intern, flipIntern] =
    useFlipSettings('ivette.globals.intern', true);
  const [extern, flipExtern] =
    useFlipSettings('ivette.globals.extern', true);
  const [evaAnalyzed, flipEvaAnalyzed] =
    useFlipSettings('ivette.globals.eva-analyzed', true);
  const [evaUnreached, flipEvaUnreached] =
    useFlipSettings('ivette.globals.eva-unreached', true);
  const [selected, flipSelected] =
    useFlipSettings('ivette.globals.selected', false);
  const { markers } = Locations.useSelection();
  const multipleSelection: States.Scope[] =
    React.useMemo(
      () => markers.map((m) => getMarker(m)?.scope)
      , [ getMarker, markers ]);
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
  }

  async function onContextMenu(): Promise<void> {
    const items: Dome.PopupMenuItem[] = [
      {
        label: 'Show Frama-C builtins',
        checked: builtin,
        onClick: flipBuiltin,
      },
      {
        label: 'Show stdlib functions',
        checked: stdlib,
        onClick: flipStdlib,
      },
      'separator',
      {
        label: 'Show defined functions',
        checked: def,
        onClick: flipDef,
      },
      {
        label: 'Show undefined functions',
        checked: undef,
        onClick: flipUndef,
      },
      'separator',
      {
        label: 'Show non-extern functions',
        checked: intern,
        onClick: flipIntern,
      },
      {
        label: 'Show extern functions',
        checked: extern,
        onClick: flipExtern,
      },
      'separator',
      {
        label: 'Show functions analyzed by Eva',
        enabled: evaComputed,
        checked: evaAnalyzed,
        onClick: flipEvaAnalyzed,
      },
      {
        label: 'Show functions unreached by Eva',
        enabled: evaComputed,
        checked: evaUnreached,
        onClick: flipEvaUnreached,
      },
      'separator',
      {
        label: 'Selected only',
        enabled: multipleSelectionActive,
        checked: selected,
        onClick: flipSelected,
      },
    ];
    Dome.popupMenu(items);
  }

  // Filtered

  const filtered = fcts.filter(showFunction);
  const nTotal = fcts.length;
  const nFilter = filtered.length;
  const title = `Functions ${nFilter} / ${nTotal}`;

  const filterButtonProps = {
    icon: 'TUNINGS',
    title: `Functions filtering options (${nFilter} / ${nTotal})`,
    onClick: onContextMenu,
  };

  const filteredFunctions =
    filtered.map((fct) => (
      <FctItem
        key={fct.key}
        fct={fct}
        current={current}
      />
    ));

  const noFunction =
    <div className='dome-xSideBarSection-content'>
      <label className='globals-info'>
        There is no function to display.
      </label>
    </div>;

  const allFiltered =
    <div className='dome-xSideBarSection-content'>
      <label className='globals-info'>
        All functions are filtered. Try adjusting function filters.
      </label>
      <Button {...filterButtonProps} label='Functions filters' />
    </div>;

  return (
    <Section
      label="Functions"
      title={title}
      defaultUnfold
      settings="frama-c.sidebar.functions"
      rightButtonProps={filterButtonProps}
      summary={[nFilter]}
      className='globals-section'
    >
      {nFilter > 0 ? filteredFunctions : nTotal > 0 ? allFiltered : noFunction}
    </Section>
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
  const { id, label, title, filter, defaultUnfold=false } = props;
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
// --- Global Variables Section
// --------------------------------------------------------------------------

const filterGlobals = (d: Ast.declAttributesData): boolean => (
  d.kind === 'GLOBAL'
);

export function Globals(): JSX.Element {
  return (
    <Declarations
      id='globals'
      label='Globals'
      title='Global Variables'
      filter={filterGlobals}
    />
  );
}

const filterTypes = (d: Ast.declAttributesData): boolean => {
  switch(d.kind) {
    case 'TYPE':
    case 'ENUM':
    case 'UNION':
    case 'STRUCT':
      return true;
    default:
      return false;
  }
};

// --------------------------------------------------------------------------
// --- Types Section
// --------------------------------------------------------------------------

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
