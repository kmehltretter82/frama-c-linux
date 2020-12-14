// --------------------------------------------------------------------------
// --- Table of (multiple) locations
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import * as Json from 'dome/data/json';
import { CompactModel } from 'dome/table/arrays';
import { Table, Column, Renderer } from 'dome/table/views';
import { Label } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Space } from 'dome/frame/toolbars';
import { Component, TitleBar } from 'frama-c/LabViews';
import { markerInfo } from 'frama-c/api/kernel/ast';

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
  const multipleSelections = selection?.multiple;
  const numberOfSelections = multipleSelections?.allSelections?.length;
  const markersInfo = States.useSyncArray(markerInfo);

  // Renderer for statement markers.
  const renderMarker: Renderer<string> =
    (loc: string) => {
      const markerId = (loc as Json.key<'#markerInfo'>);
      const info = markersInfo.getData(markerId);
      const sloc = info?.sloc;
      const position = `${sloc?.base}:${sloc?.line}`;
      return <Label label={position} title={info?.descr} />;
    };

  // Updates [[model]] with the current multiple selections.
  React.useEffect(() => {
    if (numberOfSelections > 0) {
      const data: LocationId[] =
        multipleSelections.allSelections.map((d, i) => ({ ...d, id: i }));
      model.replaceAllDataWith(data);
    } else
      model.clear();
  }, [numberOfSelections, multipleSelections, model]);

  // Callbacks
  const onTableSelection = React.useCallback(
    ({ id }) => updateSelection({ index: id }),
    [updateSelection],
  );

  const reload = () => {
    const location = multipleSelections.allSelections[multipleSelections.index];
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
          enabled={numberOfSelections > 1 && multipleSelections?.index > 0}
          title="Previous location"
        />
        <IconButton
          icon="ANGLE.RIGHT"
          onClick={() => updateSelection('MULTIPLE_NEXT')}
          enabled={
            numberOfSelections > 1 &&
            multipleSelections?.index < numberOfSelections - 1
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
          {multipleSelections?.allSelections.length === 0 ?
            '0 / 0' :
            `${multipleSelections?.index + 1} / ${numberOfSelections}`}
        </Label>
        <Space />
        <IconButton
          icon="TRASH"
          onClick={() => updateSelection('MULTIPLE_CLEAR')}
          enabled={numberOfSelections > 0}
          title={`Clear location${numberOfSelections > 1 ? 's' : ''}`}
        />
      </TitleBar>
      <Label
        label={multipleSelections?.name}
        title={multipleSelections?.title}
        style={{ textAlign: 'center' }}
      />
      <Table
        model={model}
        selection={multipleSelections?.index}
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
        <Column
          id="marker"
          label="Statement"
          fill
          render={renderMarker}
        />
      </Table>
    </>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.locations"
    label="Locations"
    title="Browse multiple locations"
  >
    <LocationsTable />
  </Component>
);

// --------------------------------------------------------------------------
