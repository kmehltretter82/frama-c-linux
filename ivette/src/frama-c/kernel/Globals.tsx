// --------------------------------------------------------------------------
// --- Frama-C Globals
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import { classes } from 'dome/misc/utils';
import { alpha } from 'dome/data/compare';
import { Section, Item } from 'dome/frame/sidebars';
import * as Ivette from 'ivette';

import * as States from 'frama-c/states';
import { functions, functionsData } from 'frama-c/api/kernel/ast';
import { isComputed } from 'frama-c/api/plugins/eva/general';

// --------------------------------------------------------------------------
// --- Global Search Hints
// --------------------------------------------------------------------------

function makeFunctionHint(fct: functionsData): Ivette.Hint {
  return {
    id: fct.key,
    label: fct.name,
    title: fct.signature,
    onSelection: () => States.setSelection({ fct: fct.name }),
  };
}

async function lookupGlobals(pattern: string): Promise<Ivette.Hint[]> {
  const lookup = pattern.toLowerCase();
  const fcts = States.getSyncArray(functions).getArray();
  return fcts.filter((fn) => (
    0 <= fn.name.toLowerCase().indexOf(lookup)
  )).map(makeFunctionHint);
}

Ivette.registerHints('frama-c.globals', lookupGlobals);

// --------------------------------------------------------------------------
// --- Function Item
// --------------------------------------------------------------------------

interface FctItemProps {
  fct: functionsData;
  current: string | undefined;
  onSelection: (name: string) => void;
}

function FctItem(props: FctItemProps) {
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

export default () => {

  // Hooks
  const [selection, updateSelection] = States.useSelection();
  const fcts = States.useSyncArray(functions).getArray().sort(
    (f, g) => alpha(f.name, g.name),
  );
  const { useFlipSettings } = Dome;
  const [stdlib, flipStdlib] =
    useFlipSettings('ivette.globals.stdlib', false);
  const [builtin, flipBuiltin] =
    useFlipSettings('ivette.globals.builtin', false);
  const [undef, flipUndef] =
    useFlipSettings('ivette.globals.undef', true);
  const [selected, flipSelected] =
    useFlipSettings('ivette.globals.selected', false);
  const [evaOnly, flipEvaOnly] =
    useFlipSettings('ivette.globals.evaonly', false);
  const multipleSelection = selection?.multiple;
  const multipleSelectionActive = multipleSelection?.allSelections.length > 0;
  const evaComputed = States.useRequest(isComputed, null);

  function isSelected(fct: functionsData) {
    return multipleSelection?.allSelections.some(
      (l) => fct.name === l?.fct
    );
  }

  // Currently selected function.
  const current: undefined | string = selection?.current?.fct;

  function showFunction(fct: functionsData) {
    const visible =
      (stdlib || !fct.stdlib)
      && (builtin || !fct.builtin)
      && (undef || fct.defined)
      && (!evaOnly || !evaComputed || (fct.eva_analyzed === true))
      && (!selected || !multipleSelectionActive || isSelected(fct));
    return visible || (current && fct.name === current);
  }

  function onSelection(name: string) {
    updateSelection({ location: { fct: name } });
  }

  async function onContextMenu() {
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
      {
        label: 'Show undefined functions',
        checked: undef,
        onClick: flipUndef,
      },
      'separator',
      {
        label: 'Selected only',
        enabled: multipleSelectionActive,
        checked: selected,
        onClick: flipSelected,
      },
      {
        label: 'Analyzed by Eva only',
        enabled: evaComputed,
        checked: evaOnly,
        onClick: flipEvaOnly,
      },
    ];
    Dome.popupMenu(items);
  }

  // Filtered

  const filtered = fcts.filter(showFunction);
  const nTotal = fcts.length;
  const nFilter = filtered.length;
  const title = `Functions ${nFilter} / ${nTotal}`;
  return (
    <Section
      label="Functions"
      title={title}
      onContextMenu={onContextMenu}
      defaultUnfold
    >
      {filtered.map((fct) => (
        <FctItem
          key={fct.name}
          fct={fct}
          current={current}
          onSelection={onSelection}
        />
      ))}
    </Section>
  );

};

// --------------------------------------------------------------------------
