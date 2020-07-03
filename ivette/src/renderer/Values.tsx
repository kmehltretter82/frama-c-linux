// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

import _ from 'lodash';
import React from 'react';
import * as States from 'frama-c/states';

import { Table, Column } from 'dome/table/views';
import { ArrayModel } from 'dome/table/arrays';
import { Component } from 'frama-c/LabViews';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';

// --------------------------------------------------------------------------
// --- Columns
// --------------------------------------------------------------------------

interface Callstack {
  id: number;
  short: string;
  full: string;
}

const ColumnCallstack = () => Column({
  id: 'callstack',
  label: 'Callstack',
  title: 'Context of the evaluation',
  align: 'left',
  width: 100,
  render: (cs: Callstack) => <Label label={cs.short} title={cs.full} />,
});

const ColumnAlarm = () => Column({
  id: 'alarm',
  label: 'Alarm',
  title: 'Did the evaluation emit an alarm?',
  align: 'center',
  width: 26,
  fixed: true,
  icon: 'WARNING',
  render: (alarm: boolean) => <>{alarm && <Icon id="ATTENTION" />}</>,
});

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface Value {
  key: string;
  callstack: Callstack;
  value_before: string;
  alarm: boolean;
  value_after?: string;
}

const Values = () => {

  const model = React.useMemo(() => new ArrayModel<Value>('key'), []);
  const items = States.useSyncArray('eva.values');
  const [select] = States.useSelection();
  const marker = select?.current?.marker;
  const t = States.useRequest('eva.values.compute', marker || '');
  const markerKinds = States.useSyncArray('kernel.ast.markerKind');
  const name = React.useRef('');

  React.useEffect(() => {
    if (marker && items) {
      const mark = markerKinds[marker];
      if (mark && mark.name) {
        name.current = mark.name;
      }
      model.replace(_.toArray(items));
    }
  }, [model, items, t, name, marker, markerKinds]);

  // Component
  return (
    <>
      <Table model={model}>
        <ColumnCallstack />
        <Column
          id="value_before"
          label={`${name.current} (before)`}
          title="Values inferred by Eva just before the selected point"
          disableSort
          fill
        />
        <ColumnAlarm />
        <Column
          id="value_after"
          label={`${name.current} (after)`}
          title="Values inferred by Eva just after the selected point"
          disableSort
          fill
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
    id="frama-c.values"
    label="Eva Values"
    title="Values inferred by the Eva analysis"
  >
    <Values />
  </Component>
);

// --------------------------------------------------------------------------
