// --------------------------------------------------------------------------
// --- Globals Side Bar
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
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
  const model = States.useSyncArray(functions);
  const forceUpdate = Dome.useForceUpdate() as (() => void);
  React.useEffect(() => {
    model.setNaturalOrder((f1, f2) => alpha(f1.name, f2.name));
    const client = model.link();
    client.onReload(forceUpdate);
    client.onUpdate(forceUpdate);
    return client.unlink;
  }, [model, forceUpdate]);

  // Functions
  const n = model.getRowCount();
  const fcts: functionsData[] = [];
  for (let i = 0; i < n; i++) {
    fcts.push(model.getRowAt(i));
  }

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
