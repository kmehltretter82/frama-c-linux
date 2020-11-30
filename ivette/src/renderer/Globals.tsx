// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import { Section, Item } from 'dome/frame/sidebars';
import type { Hint } from 'dome/frame/toolbars';
import * as States from 'frama-c/states';
import { alpha } from 'dome/data/compare';
import { functions, functionsData } from 'frama-c/api/kernel/ast';
import { isComputed } from 'frama-c/api/plugins/eva/general';

import * as Dome from 'dome';

// --------------------------------------------------------------------------
// --- Filters
// --------------------------------------------------------------------------

const defaultFilter =
  {
    stdlib: false, // Show functions from the Frama-C stdlib
    builtin: false, // Show Frama-C builtins
    undef: true, // Show undefined functions
    eva_only: false, // Only show functions analyzed by Eva
    selected_only: false, // Only show functions from a multiple selection
  };

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
  const [filter, setFilter] = React.useState(defaultFilter);
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
      (filter.stdlib || !fct.stdlib)
      && (filter.builtin || !fct.builtin)
      && (filter.undef || fct.defined)
      && (!filter.eva_only || !evaComputed || (fct.eva_analyzed === true))
      && (!filter.selected_only || !multipleSelectionActive || isSelected(fct));
    return visible;
  }

  async function onContextMenu() {
    const items: Dome.PopupMenuItem[] = [];
    items.push({
      label: 'Show Frama-C builtins',
      checked: filter.builtin,
      onClick: () => setFilter({ ...filter, builtin: !filter.builtin }),
    });
    items.push({
      label: 'Show stdlib functions',
      checked: filter.stdlib,
      onClick: () => setFilter({ ...filter, stdlib: !filter.stdlib }),
    });
    items.push({
      label: 'Show undefined functions',
      checked: filter.undef,
      onClick: () => setFilter({ ...filter, undef: !filter.undef }),
    });
    items.push('separator');
    items.push({
      label: 'Selected only',
      enabled: multipleSelectionActive,
      checked: filter.selected_only,
      onClick: () => {
        setFilter({ ...filter, selected_only: !filter.selected_only });
      },
    });
    items.push({
      label: 'Analyzed by Eva only',
      enabled: evaComputed,
      checked: filter.eva_only,
      onClick: () => setFilter({ ...filter, eva_only: !filter.eva_only }),
    });
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

  return (
    <Section label="Functions" onContextMenu={onContextMenu} defaultUnfold>
      {fcts.filter(showFunction).map(makeFctItem)}
    </Section>
  );

};

// --------------------------------------------------------------------------
