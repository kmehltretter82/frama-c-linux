// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash';
import React from 'react';
import * as States from 'frama-c/states';
import * as Compare from 'dome/data/compare';
import { Label, Code } from 'dome/controls/labels';
import { ArrayModel } from 'dome/table/arrays';
import { Table, Column, ColumnProps, Renderer } from 'dome/table/views';
import { Component } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Property Columns
// --------------------------------------------------------------------------

export const renderCode: Renderer<string> =
  (text?: string) => (text ? <Code>{text}</Code> : null);

function ColumnCode<Row>(props: ColumnProps<Row, string>) {
  return <Column render={renderCode} {...props} />;
}

interface Tag { name: string; label: string; descr: string }

export const renderTag: Renderer<Tag> =
  (d?: Tag) => (d ? <Label label={d.label} title={d.descr} /> : null);

function ColumnTag<Row>(props: ColumnProps<Row, Tag>) {
  return <Column render={renderTag} {...props} />;
}

// --------------------------------------------------------------------------
// --- Properties Table
// -------------------------------------------------------------------------

interface SourceLoc {
  file: string;
  line: number;
}

interface Property {
  key: string;
  descr: string;
  kind: string;
  status: string;
  function?: string;
  kinstr: string;
  source: SourceLoc;
}

const bySource =
  Compare.byFields<SourceLoc>({ file: Compare.alpha, line: Compare.primitive });

const byStatus =
  Compare.byRank(
    'inconsistent',
    'invalid',
    'invalid_under_hyp',
    'unknown',
    'valid_under_hyp',
    'valid',
    'invalid_but_dead',
    'unknown_but_dead',
    'valid_but_dead',
    'never_tried',
    'considered_valid',
  );

const byProperty: Compare.ByFields<Property> = {
  status: byStatus,
  function: Compare.defined(Compare.alpha),
  source: bySource,
  kind: Compare.primitive,
  key: Compare.primitive,
  kinstr: Compare.primitive,
};

class PropertyModel extends ArrayModel<Property> {
  constructor() {
    super('key');
    this.setOrderingByFields(byProperty);
  }
}

const RenderTable = () => {
  // Hooks
  const model = React.useMemo(() => new PropertyModel(), []);
  const properties: { [key: string]: Property } =
    States.useSyncArray('kernel.properties');
  const statusDict: { [status: string]: Tag } =
    States.useDictionary('kernel.dictionary.propstatus');
  const [selection, updateSelection] =
    States.useSelection();

  React.useEffect(() => {
    const data = _.toArray(properties);
    model.replace(data);
  }, [model, properties]);

  // Callbacks
  const getStatus = React.useCallback(
    ({ status: st }: Property) => (statusDict[st] ?? { label: st }),
    [statusDict],
  );

  const onPropertySelection = React.useCallback(
    ({ key, function: fct }: Property) => {
      if (fct) {
        const location = { function: fct, marker: key };
        updateSelection({ location });
      }
    }, [updateSelection],
  );

  const propertySelection = selection?.current?.marker;

  // Rendering
  return (
    <Table<string, Property>
      model={model}
      sorting={model}
      selection={propertySelection}
      onSelection={onPropertySelection}
      settings="ivette.properties.table"
    >
      <ColumnCode id="function" label="Function" width={120} />
      <ColumnCode id="descr" label="Description" fill />
      <ColumnTag
        id="status"
        label="Status"
        fixed
        width={80}
        align="center"
        getter={getStatus}
      />
    </Table>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// -------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.properties"
    label="Properties"
    title="Registered ACSL properties status"
  >
    <RenderTable />
  </Component>
);

// --------------------------------------------------------------------------
