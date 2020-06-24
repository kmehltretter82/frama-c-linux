// --------------------------------------------------------------------------
// --- Table of multiple selection
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import { ArrayModel } from 'dome/table/arrays';
import { Table, Column } from 'dome/table/views';
import { Label } from 'dome/controls/labels';
import * as Toolbar from 'dome/frame/toolbars';
import { Component } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Multiple Selection Panel
// --------------------------------------------------------------------------

const SelectionTable = () => {

  // Hooks
  const [selection, updateSelection] = States.useSelection();
  const length = selection?.multiple?.length;
  const multiple: States.Location[] = selection?.multiple;
  const model = React.useMemo(() => new ArrayModel('id'), []);

  // Updates [[model]] with the current multiple selection.
  React.useEffect(() => {
    if (multiple?.length > 0) {
      const array = multiple.map((d, i) => ({ ...d, id: i }));
      model.replace(array);
    } else
      model.clear();
  }, [multiple, model]);

  // Callbacks
  const onTableSelection = React.useCallback(
    ({ id }) => updateSelection({ index: id }),
    [updateSelection],
  );

  const reload = () => {
    const location = multiple[selection?.index];
    updateSelection({ location });
  };

  // Component
  return (
    <>
      <Toolbar.ToolBar>
        <Toolbar.Button
          icon="RELOAD"
          onClick={reload}
          enabled={length > 1}
          title="Reload the current location of the multiple selection"
        />
        <Toolbar.ButtonGroup>
          <Toolbar.Button
            icon="ANGLE.LEFT"
            onClick={() => updateSelection('PREV')}
            enabled={length > 1 && selection?.index > 0}
            title="Previous location of the multiple selection"
          />
          <Toolbar.Button
            icon="ANGLE.RIGHT"
            onClick={() => updateSelection('NEXT')}
            enabled={length > 1 && selection?.index < length - 1}
            title="Next location of the multiple selection"
          />
        </Toolbar.ButtonGroup>
        <Label
          className="component-info"
          title={`${length} selected locations`}
          display={length > 1}
        >
          {selection?.index + 1} / {length}
        </Label>
        <Toolbar.Filler />
        <Toolbar.Button
          icon="CIRC.CLOSE"
          onClick={() => updateSelection('CLEAR')}
          enabled={length > 1}
          title="Clear the multiple selection"
        />
      </Toolbar.ToolBar>
      <Table
        model={model}
        selection={selection?.index}
        onSelection={onTableSelection}
      >
        <Column
          id="id"
          label="#"
          align="center"
          width={25}
          getter={(r: {id: number}) => r.id + 1}
        />
        <Column id="function" label="Function" width={120} />
        <Column id="marker" label="Marker" fill />
      </Table>
    </>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.selection"
    label="Multiple Selection"
    title="Browse a selection of multiple locations"
  >
    <SelectionTable />
  </Component>
);

// --------------------------------------------------------------------------
