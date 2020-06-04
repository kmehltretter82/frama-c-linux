// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import { toArray, Dictionary } from 'lodash';
import { Section, Item } from 'dome/frame/sidebars';
import * as States from 'frama-c/states';


// --------------------------------------------------------------------------
// --- Globals API
// --------------------------------------------------------------------------

interface Global {
  key: string;
  kind: 'function' | 'variable' | 'typedef';
  name: string;
  descr: string;
}

type Globals = undefined | Dictionary<Global>;

// --------------------------------------------------------------------------
// --- Globals Section
// --------------------------------------------------------------------------

export default () => {

  // Hooks
  const [select, setSelect] = States.useSelection();
  const globals: Globals = States.useSyncArray('kernel.ast.globals');

  // Functions
  const functions =
    toArray(globals)
      .filter((g) => g.kind === 'function' && g.name)
      .sort((g1, g2) => {
        if (g1.name < g2.name) return -1;
        if (g1.name > g2.name) return 1;
        return 0;
      });

  const current: undefined | string = select?.function;
  const makeFctItem = (fct: Global) => {
    const kf = fct.name;
    return (
      <Item
        key={kf}
        label={kf}
        title={fct.descr}
        selected={kf === current}
        onSelection={() => setSelect({ function: kf })}
      />
    );
  };

  return (
    <Section label='Functions'>
      {functions.map(makeFctItem)}
    </Section>
  );

};

// --------------------------------------------------------------------------
