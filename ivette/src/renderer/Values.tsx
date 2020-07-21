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

const CallstackRenderer = (
  (cs: Eva.callstack) => <Label label={cs.short} title={cs.full} />
);

const ColumnCallstack = () => Column({
  id: 'callstack',
  label: 'Callstack',
  title: 'Context of the evaluation',
  align: 'left',
  width: 100,
  render: CallstackRenderer,
});

const AlarmRenderer = (
  (alarm: boolean) => <>{alarm && <Icon id="ATTENTION" />}</>
);

const ColumnAlarm = (props: { visible: boolean }) => Column({
  id: 'alarm',
  label: 'Alarm',
  title: 'Did the evaluation emit an alarm?',
  align: 'center',
  width: 26,
  fixed: true,
  icon: 'WARNING',
  visible: props.visible,
  render: AlarmRenderer,
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
  const markerInfo = States.useSyncArray(Ast.markerInfo).getArray();
  const [name, setName] = React.useState<string | undefined>(undefined);

  States.useRequest(Eva.getValues, selectMarker);

  React.useEffect(() => {
    if (selectMarker && evaValues) {
      model.removeAllData();
      const selectMarkerInfo = markerInfo.find((e) => e.key === selectMarker);
      if (selectMarkerInfo && selectMarkerInfo.var !== 'function') {
        switch (selectMarkerInfo.kind) {
          case 'expression':
          case 'lvalue':
            evaValues.forEach((i) => model.setData(i.key, i));
            setName(selectMarkerInfo.descr);
            break;
          case 'declaration':
            evaValues.forEach((i) => model.setData(i.key, i));
            setName(selectMarkerInfo.name);
            break;
          default:
            setName(undefined);
        }
      }
      model.reload();
    } else {
      setName(undefined);
    }
  }, [evaValues, selectMarker, markerInfo, model]);

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
        />
        <ColumnAlarm visible={!!name} />
        <Column
          id="value_after"
          visible={!!name}
          label={name && `${name} (after)`}
          title="Values inferred by Eva just after the selected point"
          disableSort
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
