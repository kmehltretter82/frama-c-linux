// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
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

import { VState, Size, callback, sizeof } from './vmodel';
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

class FontSizer {
  a = 0;
  b = 0;
  k: number;
  p: number;
  constructor(k: number, p: number) {
    this.k = k;
    this.p = p;
  }

  push(x: number, y: number) {
    const a0 = this.a;
    const b0 = this.b;
    if (x !== a0 && a0 !== 0) {
      const k = (y - b0) / (x - a0);
      const p = y - k * x;
      this.k = Math.round(k);
      this.p = Math.round(p);
    }
    this.a = x;
    this.b = y;
  }

  capacity(y: number) {
    return Math.round(0.5 + (y - this.p) / this.k);
  }

  compute(n: number) {
    return this.p + n * this.k;
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
// --- Values Row
// --------------------------------------------------------------------------

interface ValuesRowProps {
  style: React.CSSProperties;
  index: number;
  data: VState;
}

function ValuesRow(props: ValuesRowProps) {
  const h = props.data.getRowHeight(props.index);
  return (<div style={props.style}>#{props.index} : {h}</div>);
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface ValuesPanelProps extends Size {
  vstate: VState;
}

function ValuesPanel(props: ValuesPanelProps) {
  const { vstate, width, height } = props;
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.compute(vstate.getRowHeight(k))
    , [vstate]);
  const wmax = WSIZER.capacity(width);
  const hmax = HSIZER.capacity(height);
  const layout = { wmax, hmax };
  vstate.setLayout(layout);
  return (
    <VariableSizeList
      itemCount={vstate.getRowCount()}
      itemKey={vstate.getRowKey}
      itemSize={getRowHeight}
      width={width}
      height={height}
      itemData={vstate}
    >
      {ValuesRow}
    </VariableSizeList>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

// WARNING: MUST HAVE SINGLE USE
function useVState(): VState {
  const vstate = React.useMemo(() => new VState(), []);
  const [age, setAge] = React.useState(0);
  React.useEffect(() => vstate.bind(age, setAge), [vstate, age, setAge]);
  Server.useSignal(Values.changed, vstate.forceReload);
  return vstate;
}

function ValuesComponent() {
  const vstate = useVState();
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
