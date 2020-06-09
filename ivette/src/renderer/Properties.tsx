// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as States from 'frama-c/states';
import * as Compare from 'dome/data/compare';
import { Label, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import * as Arrays from 'dome/table/arrays';
import { Table, Column, ColumnProps, Renderer } from 'dome/table/views';
import { TitleBar, Component } from 'frama-c/LabViews';
import { Vfill } from 'dome/layout/boxes';
import { Splitter } from 'dome/layout/splitters';
import { Form, Section, FieldCheckbox } from 'dome/layout/forms';

// --------------------------------------------------------------------------
// --- Filters
// --------------------------------------------------------------------------

const defaultStatusFilter =
{
  valid: true,
  valid_hyp: true,
  unknown: true,
  invalid: true,
  invalid_hyp: true,
  considered_valid: false,
  untried: false,
  dead: false,
  inconsistent: true,
};

const defaultKindFilter =
{
  assert: true,
  invariant: true,
  variant: true,
  requires: true,
  ensures: true,
  instance: true,
  assumes: true,
  assigns: true,
  from: true,
  allocates: true,
  behavior: false,
  reachable: false,
  axiomatic: true,
  pragma: true,
  others: true,
};

const defaultAlarmsFilter =
{
  alarms: true, // show properties that are alarms
  others: true, // show properties that are not alarms
  overflow: true,
  division_by_zero: true,
  mem_access: true,
  index_bound: true,
  pointer_value: true,
  shift: true,
  ptr_comparison: true,
  differing_blocks: true,
  separation: true,
  overlap: true,
  initialization: true,
  dangling_pointer: true,
  special_float: true,
  float_to_int: true,
  function_pointer: true,
  union_initialization: true,
  bool_value: true,
};

const defaultFilter =
{
  currentFunction: false,
  status: defaultStatusFilter,
  kind: defaultKindFilter,
  alarms: defaultAlarmsFilter,
};


function filterStatus(f: typeof defaultStatusFilter, status: string) {
  switch (status) {
    case 'valid':
    case 'valid_but_dead': return f.valid;
    case 'valid_under_hyp': return f.valid_hyp;
    case 'invalid':
    case 'invalid_but_dead': return f.invalid;
    case 'invalid_under_hyp': return f.invalid_hyp;
    case 'unknown':
    case 'unknown_but_dead': return f.unknown;
    case 'considered_valid': return f.considered_valid;
    case 'never_tried': return f.untried;
    case 'dead': return f.dead;
    case 'inconsistent': return f.inconsistent;
    default: return true;
  }
}

function filterKind(f: typeof defaultKindFilter, kind: string) {
  switch (kind) {
    case 'assert': return f.assert;
    case 'invariant': return f.invariant;
    case 'variant': return f.variant;
    case 'requires': return f.requires;
    case 'ensures': return f.ensures;
    case 'instance': return f.instance;
    case 'assigns': return f.assigns;
    case 'from': return f.from;
    case 'allocates': return f.allocates;
    case 'behavior': return f.behavior;
    case 'reachable': return f.reachable;
    case 'axiomatic': return f.axiomatic;
    case 'pragma': return f.pragma;
    default: return f.others;
  }
}

function filterAlarm(f: typeof defaultAlarmsFilter, alarm: string) {
  switch (alarm) {
    case 'overflow': return f.overflow;
    case 'division_by_zero': return f.division_by_zero;
    case 'mem_access': return f.mem_access;
    case 'index_bound': return f.index_bound;
    case 'pointer_value': return f.pointer_value;
    case 'shift': return f.shift;
    case 'ptr_comparison': return f.ptr_comparison;
    case 'differing_blocks': return f.differing_blocks;
    case 'separation': return f.separation;
    case 'overlap': return f.overlap;
    case 'initialization': return f.initialization;
    case 'dangling_pointer': return f.dangling_pointer;
    case 'is_nan_or_infinite':
    case 'is_nan': return f.special_float;
    case 'float_to_int': return f.float_to_int;
    case 'function_pointer': return f.function_pointer;
    case 'initialization_of_union': return f.union_initialization;
    case 'bool_value': return f.bool_value;
    default: return true;
  }
}

function filterProperty(f: typeof defaultFilter, item: Property) {
  return filterStatus(f.status, item.status)
    && filterKind(f.kind, item.kind)
    && ((item.alarm && f.alarms.alarms)
      || (!item.alarm && f.alarms.others))
    && (!item.alarm || filterAlarm(f.alarms, item.alarm));
}

// --------------------------------------------------------------------------
// --- Property Columns
// --------------------------------------------------------------------------

const renderCode: Renderer<string> =
  (text: string) => (<Code className="code-column">{text}</Code>);

interface Tag { name: string; label: string; descr: string }

const renderTag: Renderer<Tag> =
  (d?: Tag) => (d ? <Label label={d.label} title={d.descr} /> : null);

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

function ColumnTag<Row>(props: ColumnProps<Row, Tag>) {
  return <Column render={renderTag} {...props} />;
}

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
  predicate: Compare.defined(Compare.alpha),
  key: Compare.primitive,
  kinstr: Compare.primitive,
};

const byDir = Compare.byFields<SourceLoc>({ dir: Compare.alpha });
const byFile = Compare.byFields<SourceLoc>({ base: Compare.alpha });

const byColumn: Arrays.ByColumns<Property> = {
  dir: Compare.byFields<Property>({ source: byDir }),
  file: Compare.byFields<Property>({ source: byFile }),
};

class PropertyModel extends Arrays.ArrayModel<Property> {

  private filterFun?: string;
  private filterProp = _.cloneDeep(defaultFilter);

  constructor() {
    super('key');
    this.setOrderingByFields(byProperty);
    this.setColumnOrder(byColumn);
    this.setFilter(this.filterItem.bind(this));
  }

  getFilterProps() {
    return this.filterProp;
  }

  setFilterFunction(kf?: string) {
    this.filterFun = kf;
    if (this.filterProp.currentFunction)
      this.reload();
  }

  filterItem(item: Property) {
    const cf = this.filterFun;
    const cp = this.filterProp;
    return (
      (!cp.currentFunction || cf === undefined || cf === item.function) &&
      filterProperty(cp, item)
    );
  }

}

// --------------------------------------------------------------------------
// --- Property Filter Form
// -------------------------------------------------------------------------

const PropertyFilter =
  (props: { model: PropertyModel }) => (
    <Vfill>
      <Form
        value={props.model.getFilterProps()}
        onChange={props.model.reload}
      >
        <FieldCheckbox label="Current function" path="currentFunction" />
        <Section label="Status" unfold path="status">
          <FieldCheckbox label="Valid" path="valid" />
          <FieldCheckbox label="Valid under hyp." path="valid_hyp" />
          <FieldCheckbox label="Unknown" path="unknown" />
          <FieldCheckbox label="Invalid" path="invalid" />
          <FieldCheckbox label="Invalid under hyp." path="invalid_hyp" />
          <FieldCheckbox label="Considered valid" path="considered_valid" />
          <FieldCheckbox label="Untried" path="untried" />
          <FieldCheckbox label="Dead" path="dead" />
          <FieldCheckbox label="Inconsistent" path="inconsistent" />
        </Section>
        <Section label="Property kind" path="kind">
          <FieldCheckbox label="Assertions" path="assert" />
          <FieldCheckbox label="Invariants" path="invariant" />
          <FieldCheckbox label="Variants" path="variant" />
          <FieldCheckbox label="Preconditions" path="requires" />
          <FieldCheckbox label="Postconditions" path="ensures" />
          <FieldCheckbox label="Instance" path="instance" />
          <FieldCheckbox label="Assigns clauses" path="assigns" />
          <FieldCheckbox label="From clauses" path="from" />
          <FieldCheckbox label="Allocates" path="allocates" />
          <FieldCheckbox label="Behaviors" path="behavior" />
          <FieldCheckbox label="Reachables" path="reachable" />
          <FieldCheckbox label="Axiomatics" path="axiomatic" />
          <FieldCheckbox label="Pragma" path="pragma" />
          <FieldCheckbox label="Others" path="others" />
        </Section>
        <Section label="Alarms" path="alarms">
          <FieldCheckbox label="Alarms" path="alarms" />
          <FieldCheckbox label="Others" path="others" />
        </Section>
        <Section label="Alarms kind" path="alarms">
          <FieldCheckbox label="Overflows" path="overflow" />
          <FieldCheckbox label="Divisions by zero" path="division_by_zero" />
          <FieldCheckbox label="Shifts" path="shift" />
          <FieldCheckbox label="Special floats" path="special_float" />
          <FieldCheckbox label="Float to int" path="float_to_int" />
          <FieldCheckbox label="_Bool values" path="bool_value" />
          <FieldCheckbox label="Memory accesses" path="mem_access" />
          <FieldCheckbox label="Index bounds" path="index_bound" />
          <FieldCheckbox label="Initializations" path="initialization" />
          <FieldCheckbox label="Dangling pointers" path="dangling_pointer" />
          <FieldCheckbox label="Pointer values" path="pointer_value" />
          <FieldCheckbox label="Function pointers" path="function_pointer" />
          <FieldCheckbox label="Pointer comparisons" path="ptr_comparison" />
          <FieldCheckbox label="Differing blocks" path="differing_blocks" />
          <FieldCheckbox label="Separations" path="separation" />
          <FieldCheckbox label="Overlaps" path="overlap" />
          <FieldCheckbox
            label="Initialization of unions"
            path="union_initialization"
          />
        </Section>
      </Form>
    </Vfill>
  );

// -------------------------------------------------------------------------
// --- Property Columns
// -------------------------------------------------------------------------

const PropertyColumns = () => {

  const statusDict: { [status: string]: Tag } =
    States.useDictionary('kernel.dictionary.propstatus');

  const getStatus = React.useCallback(
    ({ status: st }: Property) => (statusDict[st] ?? { label: st }),
    [statusDict],
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
      <ColumnCode id="kind" label="Property kind" width={120} />
      <ColumnCode id="alarm" label="Alarms" width={160} />
      <Column
        id="names"
        label="Names"
        width={240}
        visible={false}
        render={renderNames}
      />
      <ColumnCode id="predicate" label="Predicate" />
      <ColumnCode id="descr" label="Property" fill visible={false} />
      <ColumnTag
        id="status"
        label="Status"
        width={100}
        align="center"
        getter={getStatus}
      />
    </>
  );

};

// -------------------------------------------------------------------------
// --- Properties Table
// -------------------------------------------------------------------------

const RenderTable = () => {
  // Hooks
  const model = React.useMemo(() => new PropertyModel(), []);
  const items: { [key: string]: Property } =
    States.useSyncArray('kernel.properties');
  const [select, setSelect] = States.useSelection();
  const [showFilter, flipFilter] =
    Dome.useSwitch('ivette.properties.showFilter', true);

  // Populating the model
  React.useEffect(() => {
    const data = _.toArray(items);
    model.replace(data);
  }, [model, items]);

  // Updating the filter
  const selectedFunction = select?.function;
  React.useEffect(() => {
    model.setFilterFunction(selectedFunction);
  }, [selectedFunction]);

  // Callbacks

  const onSelection = React.useCallback(
    ({ key, function: fct }: Property) => {
      setSelect({ marker: key, function: fct });
    }, [setSelect],
  );

  const selection = select?.marker;

  return (
    <>
      <TitleBar>
        <IconButton icon='ITEMS.LIST' selected={showFilter} onClick={flipFilter} />
      </TitleBar>
      <Splitter dir="RIGHT" unfold={showFilter}>
        <Table<string, Property>
          model={model}
          sorting={model}
          selection={selection}
          onSelection={onSelection}
          settings="ivette.properties.table"
        >
          <PropertyColumns />
        </Table>
        <PropertyFilter model={model} />
      </Splitter>
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
