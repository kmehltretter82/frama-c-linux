// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash';
import React, { useEffect } from 'react';
import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import * as States from 'frama-c/states';
import * as Compare from 'dome/data/compare';
import * as Settings from 'dome/data/settings';
import { Label, Code } from 'dome/controls/labels';
import { IconButton, Checkbox } from 'dome/controls/buttons';
import * as Models from 'dome/table/models';
import * as Arrays from 'dome/table/arrays';
import { Table, Column, ColumnProps, Renderer } from 'dome/table/views';
import { TitleBar, Component } from 'frama-c/LabViews';
import { Scroll, Folder } from 'dome/layout/boxes';

import { RSplit } from 'dome/layout/splitters';

import { source as SourceLoc } from 'frama-c/api/kernel/services';
import { statusData as Property } from 'frama-c/api/kernel/properties';
import * as Properties from 'frama-c/api/kernel/properties';

// --------------------------------------------------------------------------
// --- Filters
// --------------------------------------------------------------------------

const DEFAULTS: { [key: string]: boolean } = {
  currentFunction: false,
  'status.valid': true,
  'status.valid_hyp': true,
  'status.unknown': true,
  'status.invalid': true,
  'status.invalid_hyp': true,
  'status.considered_valid': false,
  'status.untried': false,
  'status.inconsistent': true,
  'kind.assert': true,
  'kind.invariant': true,
  'kind.variant': true,
  'kind.requires': true,
  'kind.ensures': true,
  'kind.instance': true,
  'kind.assumes': true,
  'kind.assigns': true,
  'kind.froms': true,
  'kind.allocates': true,
  'kind.behavior': false,
  'kind.reachable': false,
  'kind.axiomatic': true,
  'kind.pragma': true,
  'kind.others': true,
  'alarms.alarms': true, // show properties that are alarms
  'alarms.others': true, // show properties that are not alarms
  'alarms.overflow': true,
  'alarms.division_by_zero': true,
  'alarms.mem_access': true,
  'alarms.index_bound': true,
  'alarms.pointer_value': true,
  'alarms.shift': true,
  'alarms.ptr_comparison': true,
  'alarms.differing_blocks': true,
  'alarms.separation': true,
  'alarms.overlap': true,
  'alarms.initialization': true,
  'alarms.dangling_pointer': true,
  'alarms.special_float': true,
  'alarms.float_to_int': true,
  'alarms.function_pointer': true,
  'alarms.union_initialization': true,
  'alarms.bool_value': true,
};

function filter(path: string) {
  const defaultValue = DEFAULTS[path] ?? true;
  return Settings.getWindowSettings(
    `ivette.properties.filter.${path}`,
    Json.jBoolean,
    defaultValue,
  );
}

function useFilter(path: string) {
  const defaultValue = DEFAULTS[path] ?? true;
  return Dome.useFlipSettings(
    `ivette.properties.filter.${path}`,
    defaultValue,
  );
}

function filterStatus(
  status: Properties.propStatus,
) {
  switch (status) {
    case 'valid':
    case 'valid_but_dead':
      return filter('status.valid');
    case 'valid_under_hyp':
      return filter('status.valid_hyp');
    case 'invalid':
    case 'invalid_but_dead':
      return filter('status.invalid');
    case 'invalid_under_hyp':
      return filter('status.invalid_hyp');
    case 'inconsistent':
      return filter('inconsistent');
    case 'unknown':
    case 'unknown_but_dead':
      return filter('status.unknown');
    case 'considered_valid':
      return filter('considered_valid');
    case 'never_tried':
      return filter('status.untried');
    default:
      return true;
  }
}

function filterKind(
  kind: Properties.propKind,
) {
  switch (kind) {
    case 'assert': return filter('kind.assert');
    case 'loop_invariant': return filter('kind.invariant');
    case 'loop_variant': return filter('kind.variant');
    case 'requires': return filter('kind.requires');
    case 'ensures': return filter('kind.ensures');
    case 'instance': return filter('kind.instance');
    case 'assigns': return filter('kind.assigns');
    case 'froms': return filter('kind.froms');
    case 'allocates': return filter('kind.allocates');
    case 'behavior': return filter('kind.behavior');
    case 'reachable': return filter('kind.reachable');
    case 'axiomatic': return filter('kind.axiomatic');
    case 'loop_pragma': return filter('kind.pragma');
    default: return filter('kind.others');
  }
}

function filterAlarm(alarm: string | undefined) {
  if (alarm) {
    if (!filter('alarms.alarms')) return false;
    switch (alarm) {
      case 'overflow': return filter('alarms.overflow');
      case 'division_by_zero': return filter('alarms.division_by_zero');
      case 'mem_access': return filter('alarms.mem_access');
      case 'index_bound': return filter('alarms.index_bound');
      case 'pointer_value': return filter('alarms.pointer_value');
      case 'shift': return filter('alarms.shift');
      case 'ptr_comparison': return filter('alarms.ptr_comparison');
      case 'differing_blocks': return filter('alarms.differing_blocks');
      case 'separation': return filter('alarms.separation');
      case 'overlap': return filter('alarms.overlap');
      case 'initialization': return filter('alarms.initialization');
      case 'dangling_pointer': return filter('alarms.dangling_pointer');
      case 'is_nan_or_infinite':
      case 'is_nan': return filter('alarms.special_float');
      case 'float_to_int': return filter('alarms.float_to_int');
      case 'function_pointer': return filter('alarms.function_pointer');
      case 'initialization_of_union':
        return filter('alarms.union_initialization');
      case 'bool_value': return filter('alarms.bool_value');
      default: return false;
    }
  }
  return filter('alarms.others');
}

function filterProperty(p: Property) {
  return filterStatus(p.status)
    && filterKind(p.kind)
    && filterAlarm(p.alarm);
}

// --------------------------------------------------------------------------
// --- Property Columns
// --------------------------------------------------------------------------

const renderCode: Renderer<string> =
  (text: string) => (<Code className="code-column" title={text}>{text}</Code>);

const renderTag: Renderer<States.Tag> =
  (d: States.Tag) => <Label label={d.label ?? d.name} title={d.descr} />;

const renderNames: Renderer<string[]> =
  (names: string[]) => {
    const label = names?.join(': ');
    return (label ? <Label label={label} /> : null);
  };

const renderDir: Renderer<SourceLoc> =
  (loc: SourceLoc) => (
    <Code className="code-column" label={loc.dir} title={loc.file} />
  );

const renderFile: Renderer<SourceLoc> =
  (loc: SourceLoc) => (
    <Code className="code-column" label={loc.base} title={loc.file} />
  );

function ColumnCode<Row>(props: ColumnProps<Row, string>) {
  return <Column render={renderCode} {...props} />;
}

function ColumnTag<Row>(props: ColumnProps<Row, States.Tag>) {
  return <Column render={renderTag} {...props} />;
}

// --------------------------------------------------------------------------
// --- Properties Table
// -------------------------------------------------------------------------

const bySource =
  Compare.byFields<SourceLoc>({ file: Compare.alpha, line: Compare.number });

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
  kind: Compare.structural,
  alarm: Compare.defined(Compare.alpha),
  names: Compare.array(Compare.alpha),
  predicate: Compare.defined(Compare.alpha),
  key: Compare.string,
  kinstr: Compare.structural,
};

const byDir = Compare.byFields<SourceLoc>({ dir: Compare.alpha });
const byFile = Compare.byFields<SourceLoc>({ base: Compare.alpha });

const byColumn: Arrays.ByColumns<Property> = {
  dir: Compare.byFields<Property>({ source: byDir }),
  file: Compare.byFields<Property>({ source: byFile }),
};

class PropertyModel extends Arrays.CompactModel<Json.key<'#status'>, Property> {

  private filterFun?: string;

  constructor() {
    super((p: Property) => p.key);
    this.setOrderingByFields(byProperty);
    this.setColumnOrder(byColumn);
    this.setFilter(this.filterItem.bind(this));
  }

  setFilterFunction(kf?: string) {
    this.filterFun = kf;
    if (filter('currentFunction')) this.reload();
  }

  filterItem(prop: Property) {
    const kf = prop.function;
    const cf = this.filterFun;
    const filteringFun = cf && filter('currentFunction');
    const filterFunction = filteringFun ? kf === cf : true;
    return filterFunction && filterProperty(prop);
  }

}

// --------------------------------------------------------------------------
// --- Property Filter Form
// -------------------------------------------------------------------------

const Reload = new Dome.Event('ivette.properties.reload');

interface SectionProps {
  label: string;
  children: React.ReactNode;
}

function Section(props: SectionProps) {
  const settings = `properties-section-${props.label}`;
  return (
    <Folder label={props.label} settings={settings}>
      {props.children}
    </Folder>
  );
}

interface CheckFieldProps {
  label: string;
  path: string;
}

function CheckField(props: CheckFieldProps) {
  const [value, setValue] = useFilter(props.path);
  const onChange = () => { setValue(); Reload.emit(); };
  return (
    <Checkbox
      style={{ display: 'block' }}
      label={props.label}
      value={value}
      onChange={onChange}
    />
  );
}

/* eslint-disable max-len */

function PropertyFilter() {
  return (
    <Scroll>
      <CheckField label="Current function" path="currentFunction" />
      <Section label="Status">
        <CheckField label="Valid" path="status.valid" />
        <CheckField label="Valid under hyp." path="status.valid_hyp" />
        <CheckField label="Unknown" path="status.unknown" />
        <CheckField label="Invalid" path="status.invalid" />
        <CheckField label="Invalid under hyp." path="status.invalid_hyp" />
        <CheckField label="Considered valid" path="status.considered_valid" />
        <CheckField label="Untried" path="status.untried" />
        <CheckField label="Inconsistent" path="status.inconsistent" />
      </Section>
      <Section label="Property kind">
        <CheckField label="Assertions" path="kind.assert" />
        <CheckField label="Invariants" path="kind.invariant" />
        <CheckField label="Variants" path="kind.variant" />
        <CheckField label="Preconditions" path="kind.requires" />
        <CheckField label="Postconditions" path="kind.ensures" />
        <CheckField label="Instance" path="kind.instance" />
        <CheckField label="Assigns clauses" path="kind.assigns" />
        <CheckField label="From clauses" path="kind.froms" />
        <CheckField label="Allocates" path="kind.allocates" />
        <CheckField label="Behaviors" path="kind.behavior" />
        <CheckField label="Reachables" path="kind.reachable" />
        <CheckField label="Axiomatics" path="kind.axiomatic" />
        <CheckField label="Pragma" path="kind.pragma" />
        <CheckField label="Others" path="kind.others" />
      </Section>
      <Section label="Alarms">
        <CheckField label="Alarms" path="alarms.alarms" />
        <CheckField label="Others" path="alarms.others" />
      </Section>
      <Section label="Alarms kind">
        <CheckField label="Overflows" path="alarms.overflow" />
        <CheckField label="Divisions by zero" path="alarms.division_by_zero" />
        <CheckField label="Shifts" path="alarms.shift" />
        <CheckField label="Special floats" path="alarms.special_float" />
        <CheckField label="Float to int" path="alarms.float_to_int" />
        <CheckField label="_Bool values" path="alarms.bool_value" />
        <CheckField label="Memory accesses" path="alarms.mem_access" />
        <CheckField label="Index bounds" path="alarms.index_bound" />
        <CheckField label="Initializations" path="alarms.initialization" />
        <CheckField label="Dangling pointers" path="alarms.dangling_pointer" />
        <CheckField label="Pointer values" path="alarms.pointer_value" />
        <CheckField label="Function pointers" path="alarms.function_pointer" />
        <CheckField label="Pointer comparisons" path="alarms.ptr_comparison" />
        <CheckField label="Differing blocks" path="alarms.differing_blocks" />
        <CheckField label="Separations" path="alarms.separation" />
        <CheckField label="Overlaps" path="alarms.overlap" />
        <CheckField label="Initialization of unions" path="alarms.union_initialization" />
      </Section>
    </Scroll>
  );
}

/* eslint-enable max-len */

// -------------------------------------------------------------------------
// --- Property Columns
// -------------------------------------------------------------------------

const PropertyColumns = () => {

  const statusDict = States.useTags(Properties.propStatusTags);
  const kindDict = States.useTags(Properties.propKindTags);
  const alarmDict = States.useTags(Properties.alarmsTags);

  const getStatus = React.useCallback(
    ({ status: st }: Property) => (statusDict.get(st) ?? { name: st }),
    [statusDict],
  );

  const getKind = React.useCallback(
    ({ kind: kd }: Property) => (kindDict.get(kd) ?? { name: kd }),
    [kindDict],
  );

  const getAlarm = React.useCallback(
    ({ alarm }: Property) => (
      alarm === undefined ? alarm : (alarmDict.get(alarm) ?? { name: alarm })
    ),
    [alarmDict],
  );

  return (
    <>
      <Column
        id="dir"
        label="Directory"
        width={240}
        visible={false}
        getter={(prop: Property) => prop?.source}
        render={renderDir}
      />
      <Column
        id="file"
        label="File"
        width={120}
        getter={(prop: Property) => prop?.source}
        render={renderFile}
      />
      <ColumnCode id="function" label="Function" width={120} />
      <ColumnTag id="kind" label="Property kind" getter={getKind} width={120} />
      <ColumnTag id="alarm" label="Alarms" getter={getAlarm} width={160} />
      <Column
        id="names"
        label="Names"
        width={240}
        visible={false}
        render={renderNames}
      />
      <ColumnCode id="predicate" label="Predicate" fill />
      <ColumnCode id="descr" label="Property" fill visible={false} />
      <ColumnTag
        id="status"
        label="Status"
        fixed
        width={100}
        align="center"
        getter={getStatus}
      />
    </>
  );

};

function FilterRatio({ model }: { model: PropertyModel }) {
  Models.useModel(model);
  const [filtered, total] = [model.getRowCount(), model.getTotalRowCount()];
  return (
    <Label
      className="component-info"
      title="Displayed Properties / Total"
      display={filtered !== total || true}
    >
      {filtered} / {total}
    </Label>
  );
}

// -------------------------------------------------------------------------
// --- Properties Table
// -------------------------------------------------------------------------

const RenderTable = () => {
  // Hooks
  const model = React.useMemo(() => new PropertyModel(), []);
  const data = States.useSyncArray(Properties.status).getArray();
  useEffect(() => {
    model.removeAllData();
    model.updateData(data);
    model.reload();
  }, [model, data]);

  const [selection, updateSelection] =
    States.useSelection();

  const [showFilter, flipFilter] =
    Dome.useFlipSettings('ivette.properties.showFilter');

  // Updating the filter
  Dome.useEvent(Reload, model.reload);
  const selectedFunction = selection?.current?.function;
  React.useEffect(() => {
    model.setFilterFunction(selectedFunction);
  }, [model, selectedFunction]);

  // Callbacks

  const onPropertySelection = React.useCallback(
    ({ key: propKey, function: fct }: Property) => {
      const location = { function: fct, marker: propKey };
      updateSelection({ location });
    }, [updateSelection],
  );

  const propertySelection = selection?.current?.marker;

  return (
    <>
      <TitleBar>
        <FilterRatio model={model} />
        <IconButton
          icon="CLIPBOARD"
          selected={showFilter}
          onClick={flipFilter}
          title="Toggle filters panel"
        />
      </TitleBar>
      <RSplit
        settings="ivette.properties.filterSplit"
        unfold={showFilter}
      >
        <Table<string, Property>
          model={model}
          sorting={model}
          selection={propertySelection}
          onSelection={onPropertySelection}
          settings="ivette.properties.table"
        >
          <PropertyColumns />
        </Table>
        <PropertyFilter />
      </RSplit>
    </>
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
