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

const renderCode: Renderer<string> =
  (text?: string) => (text ? <Code>{text}</Code> : null);

function ColumnCode<Row>(props: ColumnProps<Row, string>) {
  return <Column render={renderCode} {...props} />;
}

interface Tag { name: string; label: string; descr: string }

const renderTag: Renderer<Tag> =
  (d?: Tag) => (d ? <Label label={d.label} title={d.descr} /> : null);

function ColumnTag<Row>(props: ColumnProps<Row, Tag>) {
  return <Column render={renderTag} {...props} />;
}

const renderNames: Renderer<string[]> =
  (names?: string[]) => {
    const label = names?.join(': ');
    return (label ? <Label label={label} /> : null);
  }

const renderFile: Renderer<SourceLoc> =
  (loc?: SourceLoc) =>
    (loc ? <Label label={loc.base} title={loc.file} /> : null);

// --------------------------------------------------------------------------
// --- Properties Table
// -------------------------------------------------------------------------

interface SourceLoc {
  dir: string;
  base: string;
  file: string;
  line: number;
}

interface Property {
  key: string;
  descr: string;
  kind: string;
  alarm?: string;
  alarm_descr?: string;
  names: string[];
  predicate: string;
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
  alarm: Compare.defined(Compare.alpha),
  names: Compare.array(Compare.alpha),
  predicate: Compare.alpha,
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
  const items: { [key: string]: Property } =
    States.useSyncArray('kernel.properties');
  const statusDict: { [status: string]: Tag } =
    States.useDictionary('kernel.dictionary.propstatus');
  const [select, setSelect] =
    States.useSelection();

  React.useEffect(() => {
    const data = _.toArray(items);
    model.replace(data);
  }, [model, items]);

  // Callbacks
  const getStatus = React.useCallback(
    ({ status: st }: Property) => (statusDict[st] ?? { label: st }),
    [statusDict],
  );

  const onSelection = React.useCallback(
    ({ key, function: fct }: Property) => {
      setSelect({ marker: key, function: fct });
    }, [setSelect],
  );

  const selection = select?.marker;

  // Rendering
  return (
    <Table<string, Property>
      model={model}
      sorting={model}
      selection={selection}
      onSelection={onSelection}
      settings="ivette.properties.table"
    >
      <Column
        id="path"
        label="Directory"
        width={240}
        visible={false}
        getter={(prop: Property) => prop.source.dir}
      />
      <Column id="source" label="File" width={120} render={renderFile} />
      <ColumnCode id="function" label="Function" width={120} />
      <ColumnCode id="kind" label="Property kind" width={120} />
      <ColumnCode id="alarm" label="Alarms" width={160} />
      <Column id="names" label="Names" width={240} visible={false}
        render={renderNames} />
      <ColumnCode id="predicate" label="Predicate" fill />
      <ColumnCode id="descr" label="Property" fill visible={false} />
      <ColumnTag
        id="status"
        label="Status"
        width={100}
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
