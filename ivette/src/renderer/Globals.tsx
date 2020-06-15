// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import { toArray, Dictionary } from 'lodash';
import { Section, Item } from 'dome/frame/sidebars';
import * as States from 'frama-c/states';
import { alpha } from 'dome/data/compare';

// --------------------------------------------------------------------------
// --- Globals API
// --------------------------------------------------------------------------

interface Gfun {
  key: string;
  name: string;
  signature: string;
}

type Gfuns = undefined | Dictionary<Gfun>;

// --------------------------------------------------------------------------
// --- Globals Section
// --------------------------------------------------------------------------

export default () => {

  // Hooks
  const [selection, updateSelection] = States.useSelection();
  const gfuns: Gfuns = States.useSyncArray('kernel.ast.functions');

  // Functions
  const functions = toArray(gfuns).sort((f1, f2) => alpha(f1.name, f2.name));

  const current: undefined | string = selection?.current?.function;
  const makeFctItem = (fct: Gfun) => {
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
      {functions.map(makeFctItem)}
    </Section>
  );

};

// --------------------------------------------------------------------------
