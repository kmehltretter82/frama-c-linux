// --------------------------------------------------------------------------
// --- Table of multiple selection
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import { CompactModel } from 'dome/table/arrays';
import { Table, Column } from 'dome/table/views';
import { Label } from 'dome/controls/labels';
import * as Toolbar from 'dome/frame/toolbars';
import { Component } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Multiple Selection Panel
// --------------------------------------------------------------------------

type SelectionId = States.Location & { id: number };

const SelectionTable = () => {

  // Hooks
  const [selection, updateSelection] = States.useSelection();
  const model = React.useMemo(() => (
    new CompactModel<number, SelectionId>(({ id }: SelectionId) => id)
  ), []);
  const multiple: States.MultipleSelection = selection?.multiple;
  const numblerOfSelections = multiple?.allSelections?.length;

  // Updates [[model]] with the current multiple selection.
  React.useEffect(() => {
    if (numblerOfSelections > 0) {
      const data: SelectionId[] =
        multiple.allSelections.map((d, i) => ({ ...d, id: i }));
      model.replaceAllDataWith(data);
    } else
      model.clear();
  }, [numblerOfSelections, multiple, model]);

  // Callbacks
  const onTableSelection = React.useCallback(
    ({ id }) => updateSelection({ index: id }),
    [updateSelection],
  );

  const reload = () => {
    const location = multiple.allSelections[multiple.index];
    updateSelection({ location });
  };

  // Component
  return (
    <>
      <Toolbar.ToolBar>
        <Toolbar.Button
          icon="RELOAD"
          onClick={reload}
          enabled={numblerOfSelections > 1}
          title="Reload the current location of the multiple selection"
        />
        <Toolbar.ButtonGroup>
          <Toolbar.Button
            icon="ANGLE.LEFT"
            onClick={() => updateSelection('MULTIPLE_PREV')}
            enabled={numblerOfSelections > 1 && multiple?.index > 0}
            title="Previous location of the multiple selection"
          />
          <Toolbar.Button
            icon="ANGLE.RIGHT"
            onClick={() => updateSelection('MULTIPLE_NEXT')}
            enabled={
              numblerOfSelections > 1 &&
              multiple?.index < numblerOfSelections - 1
            }
            title="Next location of the multiple selection"
          />
        </Toolbar.ButtonGroup>
        <Label
          className="component-info"
          title={`${numblerOfSelections} selected locations`}
          display={numblerOfSelections > 1}
        >
          {multiple?.index + 1} / {numblerOfSelections}
        </Label>
        <Toolbar.Filler />
        <Toolbar.Button
          icon="CIRC.CLOSE"
          onClick={() => updateSelection('MULTIPLE_CLEAR')}
          enabled={numblerOfSelections > 1}
          title="Clear the multiple selection"
        />
      </Toolbar.ToolBar>
      <Table
        model={model}
        selection={multiple?.index}
        onSelection={onTableSelection}
      >
        <Column
          id="id"
          label="#"
          align="center"
          width={25}
          getter={(r: { id: number }) => r.id + 1}
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
