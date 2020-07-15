// --------------------------------------------------------------------------
// --- Table of (multiple) locations
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import { CompactModel } from 'dome/table/arrays';
import { Table, Column } from 'dome/table/views';
import { Label } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Space } from 'dome/frame/toolbars';
import { Component, TitleBar } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Locations Panel
// --------------------------------------------------------------------------

type LocationId = States.Location & { id: number };

const LocationsTable = () => {

  // Hooks
  const [selection, updateSelection] = States.useSelection();
  const model = React.useMemo(() => (
    new CompactModel<number, LocationId>(({ id }: LocationId) => id)
  ), []);
  const multiple: States.MultipleSelection = selection?.multiple;
  const numberOfSelections = multiple?.allSelections?.length;

  // Updates [[model]] with the current multiple selection.
  React.useEffect(() => {
    if (numberOfSelections > 0) {
      const data: LocationId[] =
        multiple.allSelections.map((d, i) => ({ ...d, id: i }));
      model.replaceAllDataWith(data);
    } else
      model.clear();
  }, [numberOfSelections, multiple, model]);

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
      <TitleBar>
        <IconButton
          icon="RELOAD"
          onClick={reload}
          enabled={numberOfSelections > 0}
          title="Reload the current location"
        />
        <IconButton
          icon="ANGLE.LEFT"
          onClick={() => updateSelection('MULTIPLE_PREV')}
          enabled={numberOfSelections > 1 && multiple?.index > 0}
          title="Previous location"
        />
        <IconButton
          icon="ANGLE.RIGHT"
          onClick={() => updateSelection('MULTIPLE_NEXT')}
          enabled={
            numberOfSelections > 1 &&
            multiple?.index < numberOfSelections - 1
          }
          title="Next location"
        />
        <Space />
        <Label
          className="component-info"
          title={
            `${numberOfSelections} selected ` +
            `location${numberOfSelections > 1 ? 's' : ''}`
          }
        >
          {multiple?.allSelections.length === 0 ?
            '0 / 0' : `${multiple?.index + 1} / ${numberOfSelections}`}
        </Label>
        <Space />
        <IconButton
          icon="TRASH"
          onClick={() => updateSelection('MULTIPLE_CLEAR')}
          enabled={numberOfSelections > 0}
          title={`Clear location${numberOfSelections > 1 ? 's' : ''}`}
        />
      </TitleBar>
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
    label="Locations"
    title="Browse a selection of multiple locations"
  >
    <LocationsTable />
  </Component>
);

// --------------------------------------------------------------------------
