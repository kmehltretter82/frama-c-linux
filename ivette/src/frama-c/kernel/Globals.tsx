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
import * as Toolbars from 'dome/frame/toolbars';

import * as States from 'frama-c/states';
import * as Kernel from 'frama-c/kernel/api/ast';
import { computationState } from 'frama-c/plugins/eva/api/general';
import * as Eva from 'frama-c/plugins/eva/api/general';

// --------------------------------------------------------------------------
// --- Global Search Hints
// --------------------------------------------------------------------------

function makeFunctionHint(fct: functionsData): Toolbars.Hint {
  return {
    id: fct.key,
    label: fct.name,
    title: fct.signature,
    value: () => States.setSelection({ fct: fct.name }),
  };
}

async function lookupGlobals(pattern: string): Promise<Toolbars.Hint[]> {
  const lookup = pattern.toLowerCase();
  const fcts = States.getSyncArray(Kernel.functions).getArray();
  return fcts.filter((fn) => (
    0 <= fn.name.toLowerCase().indexOf(lookup)
  )).map(makeFunctionHint);
}

Toolbars.registerSearchHints('frama-c.globals', lookupGlobals);

// --------------------------------------------------------------------------
// --- Function Item
// --------------------------------------------------------------------------

interface FctItemProps {
  fct: functionsData;
  current: string | undefined;
  onSelection: (name: string) => void;
}

function FctItem(props: FctItemProps): JSX.Element {
  const { name, signature, main, stdlib, builtin, defined } = props.fct;
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
      onSelection={() => props.onSelection(name)}
    >
      {attributes && <span className="globals-attr">{attributes}</span>}
    </Item>
  );
}

// --------------------------------------------------------------------------
// --- Globals Section(s)
// --------------------------------------------------------------------------

type functionsData =
  Kernel.functionsData | (Kernel.functionsData & Eva.functionsData);

type FctKey = Json.key<'#functions'>;

function computeFcts(
  ker: States.ArrayProxy<FctKey, Kernel.functionsData>,
  eva: States.ArrayProxy<FctKey, Eva.functionsData>,
): functionsData[] {
  const arr: functionsData[] = [];
  ker.forEach((kf) => {
    const ef = eva.getData(kf.key);
    arr.push({ ...ef, ...kf });
  });
  return arr.sort((f, g) => alpha(f.name, g.name));
}

export default function Globals(): JSX.Element {

  // Hooks
  const [selection, updateSelection] = States.useSelection();
  const ker = States.useSyncArrayProxy(Kernel.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
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
  const multipleSelection = selection?.multiple;
  const multipleSelectionActive = multipleSelection?.allSelections.length > 0;
  const evaComputed = States.useSyncValue(computationState) === 'computed';

  function isSelected(fct: functionsData): boolean {
    return multipleSelection?.allSelections.some(
      (l) => fct.name === l?.fct,
    );
  }

  // Currently selected function.
  const current: undefined | string = selection?.current?.fct;

  function showFunction(fct: functionsData): boolean {
    const visible =
      (stdlib || !fct.stdlib)
      && (builtin || !fct.builtin)
      && (def || !fct.defined)
      && (undef || fct.defined)
      && (intern || fct.extern)
      && (extern || !fct.extern)
      && (evaAnalyzed || !evaComputed ||
        !('eva_analyzed' in fct && fct.eva_analyzed === true))
      && (evaUnreached || !evaComputed ||
        ('eva_analyzed' in fct && fct.eva_analyzed === true))
      && (!selected || !multipleSelectionActive || isSelected(fct));
    return !!visible;
  }

  function onSelection(name: string): void {
    updateSelection({ location: { fct: name } });
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
        key={fct.name}
        fct={fct}
        current={current}
        onSelection={onSelection}
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
      settings="frama-c.sidebar.globals"
      rightButtonProps={filterButtonProps}
      summary={[nFilter]}
      className='globals-function-section'
    >
      {nFilter > 0 ? filteredFunctions : nTotal > 0 ? allFiltered : noFunction}
    </Section>
  );

}

// --------------------------------------------------------------------------
