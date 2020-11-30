// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import { Section, Item } from 'dome/frame/sidebars';
import type { Hint } from 'dome/frame/toolbars';
import * as States from 'frama-c/states';
import { useFlipSettings } from 'dome';
import { alpha } from 'dome/data/compare';
import { functions, functionsData } from 'frama-c/api/kernel/ast';
import { isComputed } from 'frama-c/api/plugins/eva/general';

import * as Dome from 'dome';

// --------------------------------------------------------------------------
// --- Global Search Hints
// --------------------------------------------------------------------------

export type GlobalHint = Hint<States.Location>;

const makeHint = (fct: functionsData): GlobalHint => ({
  id: fct.key,
  label: fct.name,
  title: fct.signature,
  value: { function: fct.name },
});

export function useHints(): [GlobalHint[], (pattern: string) => void] {
  const fcts = States.useSyncArray(functions).getArray();
  const [hints, setHints] = React.useState<GlobalHint[]>([]);
  const onSearch = (pattern: string) => {
    if (pattern === '') setHints([]);
    else {
      const p = pattern.toLowerCase();
      setHints(fcts.filter((fn) => (
        0 <= fn.name.toLowerCase().indexOf(p)
      )).map(makeHint));
    }
  };
  return [hints, onSearch];
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
  const [stdlib, flipStdlib] = useFlipSettings('ivette.globals.stdlib', false);
  const [builtin, flipBuiltin] = useFlipSettings('ivette.globals.builtin', false);
  const [undef, flipUndef] = useFlipSettings('ivette.globals.undef', true);
  const [selected, flipSelected] = useFlipSettings('ivette.globals.selected', false);
  const [evaOnly, flipEvaOnly] = useFlipSettings('ivette.globals.evaonly', false);
  const multipleSelection = selection?.multiple;
  const multipleSelectionActive = multipleSelection?.allSelections.length > 0;
  const evaComputed = States.useRequest(isComputed, null);

  function isSelected(fct: functionsData) {
    return multipleSelection?.allSelections.some(
      (l) => fct.name === l?.function
    );
  }

  function showFunction(fct: functionsData) {
    const visible =
      (stdlib || !fct.stdlib)
      && (builtin || !fct.builtin)
      && (undef || fct.defined)
      && (!evaOnly || !evaComputed || (fct.eva_analyzed === true))
      && (!selected || !multipleSelectionActive || isSelected(fct));
    return visible;
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
      }
    ];
    Dome.popupMenu(items);
  }

  // Items
  const current: undefined | string = selection?.current?.function;
  const makeFctItem = (fct: functionsData) => {
    const { name } = fct;
    return (
      <Item
        key={name}
        label={name}
        title={fct.signature}
        selected={name === current}
        onSelection={() => updateSelection({ location: { function: name } })}
      />
    );
  };

  // Filtered

  const filtered = fcts.filter(showFunction);
  const nTotal = fcts.length;
  const nFilter = filtered.length;
  const title = `Filtered ${nFilter} / ${nTotal}`;
  return (
    <Section
      label="Functions"
      title={title}
      onContextMenu={onContextMenu} defaultUnfold>
      {filtered.map(makeFctItem)}
    </Section>
  );

}

// --------------------------------------------------------------------------
