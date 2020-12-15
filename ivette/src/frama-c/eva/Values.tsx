// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import * as Dome from 'dome';
import { VariableSizeList } from 'react-window';
import { Vfill, Hpack, Filler } from 'dome/layout/boxes';
import { Label, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values';

// Locals

import { VState, Probe, Size, callback, sizeof } from './vmodel';
import './style.css';

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

interface ProbePanelProps {
  transient?: boolean;
  label?: string;
  code?: string;
  stmt?: string;
  onPersistent?: callback;
  onTransient?: callback;
}

function ProbePanel(props: ProbePanelProps) {
  const { transient = false, label, code, stmt } = props;
  const { width, height } = sizeof(code);
  return (
    <Hpack className="eva-probe">
      <Label className="eva-probe-label">{label && `${label}:`}</Label>
      <div className="eva-probe-code">
        <SizedArea width={width} height={height}>{code}</SizedArea>
      </div>
      <Code className="eva-probe-stmt">{stmt}</Code>
      <IconButton
        className="eva-probe-button"
        visible={!!code}
        kind={transient ? 'positive' : 'negative'}
        icon={transient ? 'CIRC.CHECK' : 'CIRC.CLOSE'}
        onClick={transient ? props.onPersistent : props.onTransient}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
      />
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Value Cell
// --------------------------------------------------------------------------

class Streamer {
  private readonly v0: number;
  private readonly vs: number[] = [];
  private v?: number;
  constructor(v0: number) {
    this.v0 = v0;
  }

  push(v: number) {
    const { vs } = this;
    vs.push(Math.round(v));
    if (vs.length > 200) vs.shift();
  }

  mean(): number {
    if (this.v === undefined) {
      const { vs } = this;
      const n = vs.length;
      if (n > 0) {
        const m = vs.reduce((s, v) => s + v, 0) / n;
        this.v = Math.round(m + 0.5);
      } else {
        this.v = this.v0;
      }
    }
    return this.v;
  }
}

class FontSizer {
  a = 0;
  b = 0;
  k: Streamer;
  p: Streamer;

  constructor(k: number, p: number) {
    this.k = new Streamer(k);
    this.p = new Streamer(p);
  }

  push(x: number, y: number) {
    const a0 = this.a;
    const b0 = this.b;
    if (x !== a0 && a0 !== 0) {
      const k = (y - b0) / (x - a0);
      const p = y - k * x;
      this.k.push(k);
      this.p.push(p);
    }
    this.a = x;
    this.b = y;
  }

  capacity(y: number) {
    const k = this.k.mean();
    const p = this.p.mean();
    return Math.round(0.5 + (y - p) / k);
  }

  dimension(n: number) {
    const k = this.k.mean();
    const p = this.p.mean();
    return p + n * k;
  }

}

const WSIZER = new FontSizer(7, 6);
const HSIZER = new FontSizer(14, 6);

interface SizedAreaProps extends Size {
  children?: React.ReactNode;
}

function SizedArea(props: SizedAreaProps) {
  const { height, width, children } = props;
  const refSizer = React.useCallback(
    (ref: null | HTMLDivElement) => {
      if (ref) {
        const r = ref.getBoundingClientRect();
        WSIZER.push(width, r.width);
        HSIZER.push(height, r.height);
      }
    }, [height, width],
  );
  return (
    <div
      ref={refSizer}
      className="eva-sized-area dome-text-code"
    >
      {children}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Update
// --------------------------------------------------------------------------

const ChangeEvent = new Dome.Event<void>('eva-changed');
const forceUpdate = () => ChangeEvent.emit();

// --------------------------------------------------------------------------
// --- Table Cell
// --------------------------------------------------------------------------

interface TableCellProps {
  probe: Probe;
}

function TableCell(props: TableCellProps) {
  const { probe } = props;
  return (
    <div className="eva-cell">
      {probe.marker}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Row
// --------------------------------------------------------------------------

interface TableRowProps {
  style: React.CSSProperties;
  index: number;
  data: VState;
}

function TableRow(props: TableRowProps) {
  Dome.useUpdate(ChangeEvent);
  const { data: vstate, index } = props;
  const row = vstate.getRow(index);
  if (!row) return null;
  let className = '';
  switch (row.kind) {
    case 'probes':
      className = 'eva-row eva-row-probes';
      break;
    case 'values':
    case 'callstack':
      className = 'eva-row eva-row-values';
      break;
  }
  const contents = row.probes.map((p) => (
    <TableCell key={p.marker} probe={p} />
  ));
  return (
    <div
      style={props.style}
    >
      <Hpack className={className}>
        {contents}
      </Hpack>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface ValuesPanelProps extends Size {
  vstate: VState;
}

function ValuesPanel(props: ValuesPanelProps) {
  const { vstate, width, height } = props;
  const listRef = React.useRef<VariableSizeList>(null);
  // --- reset line cache
  const forceLayout = React.useCallback(
    () => {
      const vlist = listRef.current;
      if (vlist) vlist.resetAfterIndex(0, true);
    }, [listRef],
  );
  // --- compute line height
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.dimension(vstate.getRowHeight(k)),
    [vstate],
  );
  // --- compute layout
  const wmax = WSIZER.capacity(width);
  const hmax = HSIZER.capacity(height);
  const hline = HSIZER.dimension(1);
  const layout = { wmax, hmax };
  vstate.setLayout(layout, forceLayout);
  // --- render list
  return (
    <VariableSizeList
      ref={listRef}
      itemCount={vstate.getRowCount()}
      itemKey={vstate.getRowKey}
      itemSize={getRowHeight}
      estimatedItemSize={hline}
      width={width}
      height={height}
      itemData={vstate}
    >
      {TableRow}
    </VariableSizeList>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

function ValuesComponent() {
  const vstate = React.useMemo(() => new VState(forceUpdate), []);
  Dome.useUpdate(ChangeEvent);
  Server.useSignal(Values.changed, forceUpdate);
  const [selection] = States.useSelection();
  const marker = selection?.current?.marker;
  const probe = vstate.focus(marker);
  const makeWindow = (size: Size) => (
    <ValuesPanel vstate={vstate} {...size} />
  );
  const rank = probe?.rank;
  const stmt = rank ? `@S${rank}` : undefined;
  return (
    <>
      <TitleBar />
      <Vfill>
        <ProbePanel
          transient={probe?.transient}
          label={probe?.label}
          code={probe?.code}
          stmt={stmt}
          onPersistent={probe?.setPersistent}
          onTransient={probe?.setTransient}
        />
        <Vfill>
          <AutoSizer>
            {makeWindow}
          </AutoSizer>
        </Vfill>
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
