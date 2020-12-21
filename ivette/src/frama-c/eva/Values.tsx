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
import { Label, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { ButtonGroup, Button } from 'dome/frame/toolbars';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as States from 'frama-c/states';

// Plugins
import * as Ast from 'frama-c/api/kernel/ast';

// Locals
import { SizedArea, HSIZER, WSIZER } from './sized';
import { Diff } from './diffed';
import { sizeof, valueAt, diffAfter, diffThen, diffElse, EvaAlarm }
  from './cells';
import { Row } from './layout';
import { Probe } from './probes';
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
  const title = `Stmt id ${stmt} at rank ${rank}`;
  return (
    <span className="dome-text-code eva-stmt" title={title}>
      @S{rank}
    </span>
  );
}

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

function ProbeInfos() {
  const model = useModel();
  const probe = model.getFocused();
  const transient = probe?.transient ?? false;
  const label = probe?.label;
  const fct = probe?.fct;
  const code = probe?.code;
  const stmt = probe?.stmt;
  const rank = probe?.rank;
  const byCS = probe?.byCallstacks;
  const stacks = model.getStacks(probe).length;
  const stackable = byCS || stacks > 1;
  const { cols, rows } = sizeof(code);
  const width = WSIZER.dimension(cols) + 4;
  const height = HSIZER.dimension(rows) + 3;
  const visible = !!code;
  const zoomed = probe?.zoomed;
  const zoomable = probe?.zoomable;
  const visibility = visible ? 'visible' : 'hidden';
  const effects = probe?.effects;
  const condition = probe?.condition;
  return (
    <Hpack style={{ visibility }} className="eva-probeinfo">
      <Label className="eva-probeinfo-label">{label && `${label}:`}</Label>
      <div style={{ minWidth: width, height }} className="eva-probeinfo-code">
        <SizedArea cols={cols} rows={rows}>{code}</SizedArea>
      </div>
      <Code>{fct}<Stmt stmt={stmt} rank={rank} /></Code>
      <IconButton
        className="eva-probeinfo-button"
        display={stackable}
        selected={byCS}
        icon="ITEMS.LIST"
        title={`Details by callstack (${stacks})`}
        onClick={() => { if (probe) probe.setByCallstacks(!byCS); }}
      />
      <IconButton
        className="eva-probeinfo-button"
        display={zoomable}
        selected={zoomed}
        icon="SEARCH"
        onClick={() => { if (probe) probe.setZoomed(!zoomed); }}
      />
      <IconButton
        className="eva-probeinfo-button"
        kind={transient ? 'selected' : 'warning'}
        icon={transient ? 'CIRC.CHECK' : 'CIRC.CLOSE'}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
        onClick={() => { if (probe) probe.setTransient(!transient); }}
      />
      <Filler />
      <ButtonGroup
        enabled={!!probe}
        value={probe?.vstate}
        onChange={(s) => { if (probe) probe.setState(s); }}
        className="eva-probeinfo-state"
      >
        <Button
          visible={effects || condition}
          label="H"
          value="Here"
        />
        <Button
          visible={condition}
          label="T"
          value="Then"
        />
        <Button
          visible={condition}
          label="E"
          value="Else"
        />
        <Button
          visible={effects}
          label="A"
          value="After"
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
    const domain =
      model.values.getValues(probe.marker, probe.stmt, callstack);
    const alarms = domain?.alarms ?? [];
    if (alarms.length > 0) {
      // console.log('ALARMS', alarms);
      const renderAlarm = ([status, alarm]: EvaAlarm) => {
        const className = `eva-alarm-info eva-alarm-${status}`;
        return (
          <Code className={className} icon="WARNING">{alarm}</Code>
        );
      };
      return (
        <Vpack className="eva-info">
          {alarms.map(renderAlarm)}
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
  const callstack = model.getCalls();
  if (callstack.length <= 1) return null;
  const makeCallsite = ({ caller, stmt, rank }: Callsite) => {
    if (!caller || !stmt) return null;
    const key = `${caller}@${stmt}`;
    const onClick = () => {
      const location = { function: caller, marker: stmt };
      setSelection({ location });
    };
    return (
      <Code
        key={key}
        icon="TRIANGLE.LEFT"
        className="eva-callsite"
        onClick={onClick}
      >
        {caller}
        <Stmt stmt={stmt} rank={rank} />
      </Code>
    );
  };
  return (
    <Hpack className="eva-info">
      {callstack.map(makeCallsite)}
    </Hpack>
  );
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

  switch (kind) {

    // ---- Probe Contents
    case 'probes':
      if (transient) {
        contents = <span className="dome-text-label">« Probe »</span>;
      } else {
        const { stmt, rank, code, label } = probe;
        const textClass = label ? 'dome-text-label' : 'dome-text-code';
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
        const domain = model.values.getValues(
          probe.marker,
          probe.stmt,
          callstack,
        );
        const { alarms = [] } = domain;
        const { vstate: s, effects, condition } = probe;
        const text = valueAt(domain, s) ?? '';
        const diff = diffAfter(domain, effects, s);
        const diffA = diffThen(domain, condition, s);
        const diffB = diffElse(domain, condition, s);
        const { cols, rows } = sizeof(text);
        contents = (
          <>
            {alarms.length > 0 && (
              <Icon className="eva-cell-alarms" size={10} id="WARNING" />
            )}
            <SizedArea cols={cols} rows={rows}>
              <span className={`eva-state-${s}`}>
                <Diff text={text} diff={diff} diffA={diffA} diffB={diffB} />
              </span>
            </SizedArea>
          </>
        );
      }
      break;

  }

  // --- Cell Packing
  const isFocused = model.getFocused() === probe;
  const className = classes(
    'eva-cell',
    transient && 'eva-transient',
    isFocused && 'eva-focused',
  );
  const onClick = () => {
    if (probe) {
      const location = { function: probe.fct, marker: probe.marker };
      setSelection({ location });
      model.setSelectedRow(row);
    }
  };
  const onDoubleClick = () => {
    if (probe) {
      if (probe.transient) probe.setTransient(false);
      if (probe.zoomable) probe.setZoomed(!probe.zoomed);
    }
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
  const sk = row.stackIndex;
  const rowKind = `eva-${kind}`;
  const rowParity = sk !== undefined && (sk % 2 === 0);
  const rowStyle =
    model.isSelectedRow(row) ? 'eva-row-selected' :
      rowParity ? 'eva-row-odd' : 'eva-row-even';
  const className = classes(
    rowKind,
    rowStyle,
  );
  const header = row.stacks && (
    <div className="eva-cell eva-stack">
      {sk === undefined ? '#' : `${1 + sk}`}
    </div>
  );
  const style: React.CSSProperties = { left: row.stacks ? 0 : 12 };
  const contents = probes.map((probe) => (
    <TableCell
      key={probe.marker}
      probe={probe}
      row={row}
    />
  ));
  return (
    <Hpack className={className} style={props.style}>
      <div style={style} className="eva-row">
        {header}
        {contents}
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
  const rowHeight = HSIZER.dimension(1);
  const [selection] = States.useSelection();
  React.useEffect(() => {
    const curr = selection?.current;
    const fct = curr?.function;
    const marker = Ast.jMarker(curr?.marker);
    model.setLayout({ zoom, margin, fct, marker });
  });
  // --- render list
  return (
    <VariableSizeList
      ref={listRef}
      itemCount={model.getRowCount()}
      itemKey={model.getRowKey}
      itemSize={getRowHeight}
      estimatedItemSize={rowHeight}
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
