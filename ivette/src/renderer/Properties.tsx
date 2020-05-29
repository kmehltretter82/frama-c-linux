// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash';
import React from 'react';
import * as States from 'frama-c/states';
import { Label, Code } from 'dome/controls/labels';
import { ArrayModel } from 'dome/table/arrays';
import { Table, Column, ColumnProps, Renderer } from 'dome/table/views';
import { Component } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Property Columns
// --------------------------------------------------------------------------

export const renderCode: Renderer<string> =
  (text?: string) => text ? <Code>{text}</Code> : null;

function ColumnCode<Row>(props: ColumnProps<Row, string>) {
  return <Column render={renderCode} {...props} />;
}

interface Tag { name: string; label: string; descr: string }

export const renderTag: Renderer<Tag> =
  (d?: Tag) => d ? <Label label={d.label} title={d.descr} /> : null;

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
  function: string;
  kinstr: string;
  source: SourceLoc;
}

const RenderTable = () => {
  // Hooks
  const model =
    React.useMemo(() => new ArrayModel<Property>('key'), []);
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
  const getStatus =
    ({ status: st }: Property) => (statusDict[st] ?? { label: st });
  const selection = select?.marker;
  const onSelection = ({ key, function: fct }: Property) => {
    setSelect({ marker: key, function: fct });
  };

  // Rendering
  return (
    <Table<string, Property>
      model={model}
      selection={selection}
      onSelection={onSelection}
      scrollTo={selection}
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
