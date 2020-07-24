// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';
import * as Json from 'dome/data/json';
import * as Eva from 'api/plugins/eva/values';
import * as Ast from 'api/kernel/ast';
import * as Compare from 'dome/data/compare';

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
  width: 150,
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

const byValues: Compare.ByFields<Eva.valuesData> =
  { callstack: Compare.defined(Compare.byFields({ full: Compare.string })) };

class ValuesModel extends ArrayModel<Json.key<'#values'>, Eva.valuesData> {
  constructor() {
    super();
    this.setOrderingByFields(byValues);
  }
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

const Values = () => {

  const model = React.useMemo(() => new ValuesModel(), []);
  const evaValues = States.useSyncArray(Eva.values).getArray();
  const selectMarker = States.useSelection()[0]?.current?.marker;
  const markerInfo = States.useSyncArray(Ast.markerInfo).getArray();
  const [name, setName] = React.useState<string | undefined>(undefined);

  States.useRequest(Eva.getValues, selectMarker);

  React.useEffect(() => {
    model.removeAllData();
    if (selectMarker && evaValues) {
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
    } else {
      setName(undefined);
    }
    model.reload();
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
          width={300}
        />
        <ColumnAlarm visible={!!name} />
        <Column
          id="value_after"
          visible={!!name}
          label={name && `${name} (after)`}
          title="Values inferred by Eva just after the selected point"
          disableSort
          width={300}
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
