// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

import _ from 'lodash';
import React from 'react';
import * as States from 'frama-c/states';

import { Table, Column, DefineColumn } from 'dome/table/views';
import { ArrayModel } from 'dome/table/arrays';
import { Component } from 'frama-c/LabViews';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';

// --------------------------------------------------------------------------
// --- Columns
// --------------------------------------------------------------------------

const CallstackColumn = DefineColumn({
  title: 'Context of the evaluation',
  align: 'left',
  width: 100,
  renderValue: (cs: any) => <Label label={cs.short} title={cs.full} />,
});

const AlarmColumn = DefineColumn({
  title: 'Did the evaluation emit an alarm?',
  align: 'center',
  width: 26,
  fixed: 'true',
  icon: 'WARNING',
  renderValue: (alarm: boolean) => {
    if (alarm)
      return <Icon id="ATTENTION" />;
    return <> </>;
  },
});

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

const Values = () => {

  const model = React.useMemo(() => new ArrayModel(), []);
  const items = States.useSyncArray('eva.values');
  const [select] = States.useSelection();
  const marker = select && select.marker;
  const t = States.useRequest('eva.values.compute', marker || '');
  const markers = States.useSyncArray('kernel.ast.markerKind');
  const name = React.useRef('');

  React.useEffect(() => {
    if (marker && items) {
      const mark = markers[marker];
      if (mark && mark.name) {
        name.current = mark.name;
      }
      model.setData(_.toArray(items));
    }
  }, [model, items, t, name, marker, markers]);

  // Component
  return (
    <>
      <Table model={model}>
        <CallstackColumn id="callstack" label="Callstack" />
        <Column
          id="value_before"
          label={`${name.current} (before)`}
          title="Values inferred by Eva just before the selected point"
          disableSort
          fill
        />
        <AlarmColumn id="alarm" label="Alarm" />
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
