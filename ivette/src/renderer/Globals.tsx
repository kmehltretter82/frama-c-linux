// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import { Section, Item } from 'dome/frame/sidebars';
import * as States from 'frama-c/states';
import { alpha } from 'dome/data/compare';
import { functions, functionsData } from 'api/kernel/ast';

// --------------------------------------------------------------------------
// --- Globals Section
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
    <Section label="Functions">
      {fcts.map(makeFctItem)}
    </Section>
  );

};

// --------------------------------------------------------------------------
