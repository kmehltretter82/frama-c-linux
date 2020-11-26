// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import { Section, Item } from 'dome/frame/sidebars';
import type { Hint } from 'dome/frame/toolbars';
import * as States from 'frama-c/states';
import { alpha } from 'dome/data/compare';
import { functions, functionsData } from 'frama-c/api/kernel/ast';

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

  // Items
  const current: undefined | string = selection?.current?.function;
  const makeFctItem = (fct: functionsData) => {
    const kf = fct.name;
    return (
      <Item
        key={kf}
        label={kf}
        title={fct.signature}
        selected={kf === current}
        onSelection={() => updateSelection({ location: { function: kf } })}
      />
    );
  };

  return (
    <Section label="Functions" defaultUnfold>
      {fcts.map(makeFctItem)}
    </Section>
  );

};

// --------------------------------------------------------------------------
