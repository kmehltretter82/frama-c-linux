// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import * as Dome from 'dome';
import { classes } from 'dome/misc/utils';
import { VariableSizeList } from 'react-window';
import { Vfill, Hpack, Vpack, Filler } from 'dome/layout/boxes';
import { Icon } from 'dome/controls/icons';
import { Label, Code, Cell } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { ButtonGroup, Button } from 'dome/frame/toolbars';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as States from 'frama-c/states';

// Locals
import { SizedArea, HSIZER, WSIZER } from './sized';
import { Diff, DiffProps } from './diffed';
import { sizeof, EvaValues, EvaState, EvaAlarm } from './cells';
import { Probe } from './probes';
import { Row } from './layout';
import { Callsite } from './stacks';
import { Model, getModelInstance } from './model';
import './style.css';

// --------------------------------------------------------------------------
// --- Use Model
// --------------------------------------------------------------------------

function useModel(): Model {
  const model = getModelInstance();
  Dome.useUpdate(model.changed, model.laidout);
  return model;
}

// --------------------------------------------------------------------------
// --- Stmt Printer
// --------------------------------------------------------------------------

interface StmtProps {
  stmt?: string;
  rank?: number;
}

function Stmt(props: StmtProps) {
  const { rank, stmt } = props;
  if (rank === undefined || !stmt) return null;
  const title = `Stmt at global rank ${rank} (internal id: ${stmt})`;
  return (
    <span className="dome-text-cell eva-stmt" title={title}>
      @S{rank}
    </span>
  );
}

// --------------------------------------------------------------------------
// --- Probe Editor
// --------------------------------------------------------------------------

function ProbeEditor() {
  const model = useModel();
  const probe = model.getFocused();
  if (!probe || !probe.code) return null;
  const { label } = probe;
  const { code } = probe;
  const { stmt } = probe;
  const { rank } = probe;
  const byCS = probe.byCallstacks;
  const stacks = model.getStacks(probe);
  const stackable = byCS || stacks.length > 1;
  const { cols, rows } = sizeof(code);
  const { transient } = probe;
  const { zoomed } = probe;
  const { zoomable } = probe;
  return (
    <>
      <Label className="eva-probeinfo-label">{label}</Label>
      <div className="eva-probeinfo-code">
        <SizedArea cols={cols} rows={rows}>{code}</SizedArea>
      </div>
      <Code><Stmt stmt={stmt} rank={rank} /></Code>
      <IconButton
        icon="ITEMS.LIST"
        className="eva-probeinfo-button"
        display={stackable}
        selected={byCS}
        title={`Details by callstack (${stacks})`}
        onClick={() => { if (probe) probe.setByCallstacks(!byCS); }}
      />
      <IconButton
        icon="SEARCH"
        className="eva-probeinfo-button"
        display={zoomable}
        selected={zoomed}
        onClick={() => { if (probe) probe.setZoomed(!zoomed); }}
      />
      <IconButton
        icon="PIN"
        className="eva-probeinfo-button"
        selected={!transient}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
        onClick={() => {
          if (probe) {
            if (transient) probe.setPersistent();
            else probe.setTransient();
          }
        }}
      />
      <IconButton
        icon="CIRC.CLOSE"
        className="eva-probeinfo-button"
        display={!transient}
        title="Discard the probe"
        onClick={() => {
          if (probe) {
            probe.setTransient();
            const p = probe.next ?? probe.prev;
            if (p) setImmediate(() => {
              States.setSelection({ fct: p.fct, marker: p.marker });
            });
            else model.clearSelection();
          }
        }}
      />
    </>
  );
}

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

function ProbeInfos() {
  const model = useModel();
  const probe = model.getFocused();
  const fct = probe?.fct;
  const byCS = probe?.byCallstacks;
  const effects = probe ? probe.effects : false;
  const condition = probe ? probe.condition : false;
  const summary = fct ? model.stacks.getSummary(fct) : false;
  const vcond = model.getVcond();
  const vstmt = model.getVstmt();
  return (
    <Hpack className="eva-probeinfo">
      <ProbeEditor />
      <Filler />
      <ButtonGroup
        enabled={!!probe}
        className="eva-probeinfo-state"
      >
        <Button
          label={'\u2211'}
          title="Show Callstacks Summary"
          selected={summary}
          visible={byCS}
          onClick={() => { if (fct) model.stacks.setSummary(fct, !summary); }}
        />
        <Button
          visible={condition}
          label="C"
          selected={vcond === 'Here'}
          title="Show values in all conditions"
          onClick={() => model.setVcond('Here')}
        />
        <Button
          visible={condition || vcond === 'Then'}
          selected={vcond === 'Then'}
          enabled={condition}
          label="T"
          value="Then"
          title="Show reduced values when condition holds (Then)"
          onClick={() => model.setVcond('Then')}
        />
        <Button
          visible={condition || vcond === 'Else'}
          selected={vcond === 'Else'}
          enabled={condition}
          label="E"
          value="Else"
          title="Show reduced values when condition does not hold (Else)"
          onClick={() => model.setVcond('Else')}
        />
        <Button
          visible={condition || effects}
          selected={vstmt === 'After'}
          label="A"
          value="After"
          title="Show values after/before statement effects"
          onClick={() => {
            model.setVstmt(vstmt === 'After' ? 'Here' : 'After');
          }}
        />
      </ButtonGroup>
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Alarms Panel
// --------------------------------------------------------------------------

function AlarmsInfo() {
  const model = useModel();
  const probe = model.getFocused();
  if (probe) {
    const callstack = model.getCallstack();
    const domain = model.values.getValues(probe, callstack);
    const alarms = domain?.alarms ?? [];
    if (alarms.length > 0) {
      const renderAlarm = ([status, alarm]: EvaAlarm) => {
        const className = `eva-alarm-info eva-alarm-${status}`;
        return (
          <Code className={className} icon="WARNING">{alarm}</Code>
        );
      };
      return (
        <Vpack className="eva-info">
          {React.Children.toArray(alarms.map(renderAlarm))}
        </Vpack>
      );
    }
  }
  return null;
}

// --------------------------------------------------------------------------
// --- Stack Panel
// --------------------------------------------------------------------------

function StackInfo() {
  const model = useModel();
  const [, setSelection] = States.useSelection();
  const focused = model.getFocused();
  const callstack = model.getCalls();
  if (callstack.length <= 1) return null;
  const makeCallsite = ({ caller, stmt, rank }: Callsite) => {
    if (!caller || !stmt) return null;
    const key = `${caller}@${stmt}`;
    const isFocused = focused?.marker === stmt;
    const isTransient = focused?.transient;
    const className = classes(
      'eva-callsite',
      isFocused && 'eva-focused',
      isTransient && 'eva-transient',
    );
    const select = (meta: boolean) => {
      const location = { fct: caller, marker: stmt };
      setSelection({ location });
      if (meta) States.MetaSelection.emit(location);
    };
    const onClick = (evt: React.MouseEvent) => {
      select(evt.altKey);
    };
    const onDoubleClick = (evt: React.MouseEvent) => {
      evt.preventDefault();
      select(true);
    };
    return (
      <Cell
        key={key}
        icon="TRIANGLE.LEFT"
        className={className}
        onClick={onClick}
        onDoubleClick={onDoubleClick}
      >
        {caller}
        <Stmt stmt={stmt} rank={rank} />
      </Cell>
    );
  };
  return (
    <Hpack className="eva-info">
      {callstack.map(makeCallsite)}
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Cell Diffs
// --------------------------------------------------------------------------

function isTrivial(v: EvaValues) {
  return v.values === '{0; 1}' &&
    v.v_then === '{1}' &&
    v.v_else === '{0}';
}

function computeDiffs(
  condition: boolean,
  v: EvaValues,
  vstate: EvaState,
): DiffProps {
  if (condition) {
    const trv = isTrivial(v);
    switch (vstate) {
      case 'Here':
      case 'After':
        return trv ? { text: v.values } :
          { text: v.values, diffA: v.v_then, diffB: v.v_else };
      case 'Then':
        return { text: v.v_then, diff: !trv ? v.values : undefined };
      case 'Else':
        return { text: v.v_else, diff: !trv ? v.values : undefined };
    }
  } else {
    switch (vstate) {
      case 'Here':
      case 'Then':
      case 'Else':
        return { text: v.values, diff: v.v_after };
      case 'After':
        return { text: v.v_after, diff: v.values };
    }
  }
}

// --------------------------------------------------------------------------
// --- Table Cell
// --------------------------------------------------------------------------

interface TableCellProps {
  probe: Probe;
  row: Row;
}

const CELLPADDING = 12;

function TableCell(props: TableCellProps) {
  const model = useModel();
  const [, setSelection] = States.useSelection();
  const { probe, row } = props;
  const { kind, callstack } = row;
  const minWidth = CELLPADDING + WSIZER.dimension(probe.minCols);
  const maxWidth = CELLPADDING + WSIZER.dimension(probe.maxCols);
  const style = { width: minWidth, maxWidth };
  let contents: React.ReactNode = props.probe.marker;
  const { transient } = probe;
  const focused = model.getFocused();
  const isFocused = focused === probe;

  switch (kind) {

    // ---- Probe Contents
    case 'probes':
      if (transient) {
        contents = <span className="dome-text-label">« Probe »</span>;
      } else {
        const { stmt, rank, code, label } = probe;
        const textClass = label ? 'dome-text-label' : 'dome-text-cell';
        contents = (
          <>
            <span className={textClass}>{label ?? code}</span>
            <Stmt stmt={stmt} rank={rank} />
          </>
        );
      }
      break;

    // ---- Values Contents
    case 'values':
    case 'callstack':
      {
        const domain = model.values.getValues(probe, callstack);
        const { alarms = [] } = domain;
        const { condition } = probe;
        const vstate = condition ? model.getVcond() : model.getVstmt();
        const vdiffs = computeDiffs(condition, domain, vstate);
        const text = vdiffs.text ?? vdiffs.diff;
        const { cols, rows } = sizeof(text);
        let status = 'none';
        if (alarms.length > 0) {
          if (alarms.find(([st, _]) => st === 'False')) status = 'False';
          else status = 'Unknown';
        }
        const alarmClass = `eva-cell-alarms eva-alarm-${status}`;
        contents = (
          <>
            <Icon className={alarmClass} size={10} id="WARNING" />
            <SizedArea cols={cols} rows={rows}>
              <span className={`eva-state-${vstate}`}>
                <Diff {...vdiffs} />
              </span>
            </SizedArea>
          </>
        );
      }
      break;

  }

  // --- Cell Packing
  const className = classes(
    'eva-cell',
    transient && 'eva-transient',
    isFocused && 'eva-focused',
  );
  const onClick = () => {
    const location = { fct: probe.fct, marker: probe.marker };
    setSelection({ location });
    model.setSelectedRow(row);
  };
  const onDoubleClick = () => {
    probe.setPersistent();
    if (probe.zoomable) probe.setZoomed(!probe.zoomed);
  };
  return (
    <div
      className={className}
      style={style}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
    >
      {contents}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Section
// --------------------------------------------------------------------------

interface TableSectionProps {
  fct: string;
  folded: boolean;
  foldable: boolean;
  onClick: () => void;
}

function TableSection(props: TableSectionProps) {
  const { fct, foldable, folded, onClick } = props;
  const icon = folded ? 'ANGLE.RIGHT' :
    foldable ? 'ANGLE.DOWN' : 'TRIANGLE.RIGHT';
  return (
    <>
      <IconButton
        className="eva-fct-fold"
        size={10}
        offset={-1}
        icon={icon}
        enabled={foldable}
        onClick={onClick}
      />
      <Cell className="eva-fct-name">{fct}</Cell>
    </>
  );
}

// --------------------------------------------------------------------------
// --- Table Row Header
// --------------------------------------------------------------------------

interface TableHeadProps {
  stackCalls: Callsite[];
  stackIndex: number | undefined;
  stackCount: number | undefined;
  onClick: () => void;
}

function makeStackTitle(calls: Callsite[]) {
  const cs = calls.slice(1);
  if (cs.length > 0)
    return `Callstack: ${cs.map((c) => c.callee).join(' \u2190 ')}`;
  return 'Callstack Details';
}

function TableHead(props: TableHeadProps) {
  const sk = props.stackIndex;
  const sc = props.stackCount;
  const hdClass = classes('eva-head', sc ? undefined : 'dome-hidden');
  const hdHeader = sk === undefined;
  const hdSummary = sk !== undefined && sk < 0;
  const hdNumber = sk === undefined ? 0 : 1 + sk;
  const hdTitle =
    hdHeader ? 'Callstack / Summary' :
      hdSummary ? 'Summary' : makeStackTitle(props.stackCalls);
  return (
    <div
      className={hdClass}
      title={hdTitle}
      onClick={props.onClick}
    >
      <div className="eva-phantom">{'\u2211'}{sc ?? '#'}</div>
      {hdHeader ? '#' : hdSummary ? '\u2211' : `${hdNumber}`}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Row
// --------------------------------------------------------------------------

interface TableRowProps {
  style: React.CSSProperties;
  index: number;
}

function TableRow(props: TableRowProps) {
  const model = useModel();
  const row = model.getRow(props.index);
  if (!row) return null;
  const { kind, probes } = row;
  if (kind === 'section') {
    const { fct } = row;
    if (!fct) return null;
    const folded = model.isFolded(fct);
    const foldable = model.isFoldable(fct);
    return (
      <Hpack className="eva-function" style={props.style}>
        <TableSection
          fct={fct}
          folded={folded}
          foldable={foldable}
          onClick={() => model.setFolded(fct, !folded)}
        />
      </Hpack>
    );
  }
  const sk = row.stackIndex;
  const sc = row.stackCount;
  const cs = row.callstack;
  const calls = cs ? model.stacks.getCalls(cs) : [];
  const rowKind = `eva-${kind}`;
  const rowParity = sk !== undefined && sk % 2 === 1;
  const rowIndexKind =
    model.isSelectedRow(row) ? 'eva-row-selected' :
      model.isAlignedRow(row) ? 'eva-row-aligned' :
        rowParity ? 'eva-row-odd' : 'eva-row-even';
  const rowClass = classes('eva-row', rowKind, rowIndexKind);
  const onHeaderClick = () => model.setSelectedRow(row);
  const makeCell = (probe: Probe) => (
    <TableCell
      key={probe.marker}
      probe={probe}
      row={row}
    />
  );
  return (
    <Hpack style={props.style}>
      <div className={rowClass}>
        <TableHead
          stackIndex={sk}
          stackCount={sc}
          stackCalls={calls}
          onClick={onHeaderClick}
        />
        {probes.map(makeCell)}
      </div>
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface Dimension {
  width: number;
  height: number;
}

interface ValuesPanelProps extends Dimension {
  zoom: number;
}

function ValuesPanel(props: ValuesPanelProps) {
  const model = useModel();
  const { zoom, width, height } = props;
  // --- reset line cache
  const listRef = React.useRef<VariableSizeList>(null);
  Dome.useEvent(model.laidout, () => {
    setImmediate(() => {
      const vlist = listRef.current;
      if (vlist) vlist.resetAfterIndex(0, true);
    });
  });
  // --- compute line height
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.dimension(model.getRowLines(k)),
    [model],
  );
  // --- compute layout
  const margin = WSIZER.capacity(width);
  const estimatedHeight = HSIZER.dimension(1);
  const [selection] = States.useSelection();
  React.useEffect(() => {
    const location = selection?.current;
    model.setLayout({ zoom, margin, location });
  });
  // --- render list
  return (
    <VariableSizeList
      ref={listRef}
      itemCount={model.getRowCount()}
      itemKey={model.getRowKey}
      itemSize={getRowHeight}
      estimatedItemSize={estimatedHeight}
      width={width}
      height={height}
      itemData={model}
    >
      {TableRow}
    </VariableSizeList>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

function ValuesComponent() {
  const [zoom, setZoom] = Dome.useNumberSettings('eva-zoom-factor', 0);
  return (
    <>
      <TitleBar>
        <IconButton
          enabled={zoom > 0}
          icon="ZOOM.OUT"
          onClick={() => setZoom(zoom - 1)}
        />
        <IconButton
          enabled={zoom < 20}
          icon="ZOOM.IN"
          onClick={() => setZoom(zoom + 1)}
        />
      </TitleBar>
      <Vfill>
        <ProbeInfos />
        <Vfill>
          <AutoSizer>
            {(dim: Dimension) => (
              <ValuesPanel
                zoom={zoom}
                {...dim}
              />
            )}
          </AutoSizer>
        </Vfill>
        <AlarmsInfo />
        <StackInfo />
      </Vfill>
    </>
  );
}

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.values"
    label="Eva Values"
    title="Values inferred by the Eva analysis"
  >
    <ValuesComponent />
  </Component>
);

// --------------------------------------------------------------------------
