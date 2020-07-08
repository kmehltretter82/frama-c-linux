// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';
import * as Json from 'dome/data/json';
import * as Eva from 'api/plugins/eva/values';
import * as Ast from 'api/kernel/ast';

import { Table, Column } from 'dome/table/views';
import { ArrayModel } from 'dome/table/arrays';
import { Component } from 'frama-c/LabViews';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';

// --------------------------------------------------------------------------
// --- Columns
// --------------------------------------------------------------------------

const ColumnCallstack = () => Column({
  id: 'callstack',
  label: 'Callstack',
  title: 'Context of the evaluation',
  align: 'left',
  width: 100,
  render: (cs: Eva.callstack) => <Label label={cs.short} title={cs.full} />,
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

const Values = () => {

  const model = React.useMemo(
    () => new ArrayModel<Json.key<'#values'>, Eva.valuesData>(),
    [],
  );

  const evaValues = States.useSyncArray(Eva.values).getArray();
  const selectMarker = States.useSelection()[0]?.current?.marker;
  const t = States.useRequest(Eva.getValues, selectMarker);
  const markerInfo = States.useSyncArray(Ast.markerInfo).getArray();
  const [name, setName] = React.useState<string | undefined>(undefined);

  React.useEffect(() => {
    if (selectMarker && evaValues) {
      model.removeAllData();
      const selectMarkerInfo = markerInfo.find((e) => e.key === selectMarker);
      if (selectMarkerInfo && selectMarkerInfo.var !== 'function') {
        switch (selectMarkerInfo.kind) {
          case 'expression':
          case 'lvalue':
            setName(selectMarkerInfo.descr);
            evaValues.forEach((i) => model.setData(i.key, i));
            break;
          case 'declaration':
            setName(selectMarkerInfo.name);
            evaValues.forEach((i) => model.setData(i.key, i));
            break;
          default:
            setName(undefined);
        }
      }
    } else {
      setName(undefined);
    }
    model.reload();
  }, [model, evaValues, t, selectMarker, markerInfo]);

  // Component
  return (
    <>
      <Table model={model}>
        <ColumnCallstack />
        <Column
          id="value_before"
          visible={!!name}
          label={name && `${name} (before)`}
          title="Values inferred by Eva just before the selected point"
          disableSort
          fill
        />
        <ColumnAlarm />
        <Column
          id="value_after"
          visible={!!name}
          label={name && `${name} (after)`}
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
