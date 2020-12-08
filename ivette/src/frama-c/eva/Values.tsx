// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import { Vfill } from 'dome/layout/boxes';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values'

/* --------------------------------------------------------------------------*/
/* --- Utilities                                                          ---*/
/* --------------------------------------------------------------------------*/

type callback = () => void;
interface Size { width: number; height: number };

/* --------------------------------------------------------------------------*/
/* --- Cell Properties                                                    ---*/
/* --------------------------------------------------------------------------*/

interface CellProps extends Size {
}

/* --------------------------------------------------------------------------*/
/* --- Row Properties                                                     ---*/
/* --------------------------------------------------------------------------*/

type RowKind = 'probes' | 'values' | 'callstack';

interface RowProps {
  kind: RowKind;
  height: number;
  cells: CellProps[];
}

/* --------------------------------------------------------------------------*/
/* --- Probe State                                                        ---*/
/* --------------------------------------------------------------------------*/

class Probe {

  marker: Readonly<string>;
  transient: boolean;

  constructor(marker: string) {
    this.marker = marker;
    this.transient = true;
  }
}

/* --------------------------------------------------------------------------*/
/* --- Values State                                                       ---*/
/* --------------------------------------------------------------------------*/

class VState {

  constructor() {
    this.forceUpdate = this.forceUpdate.bind(this);
    this.forceReload = this.forceReload.bind(this);
  }

  //--- Probes
  private focused?: Probe;
  private probes = new Map<string, Probe>();

  getProbe(m: string): Probe {
    let p = this.probes.get(m);
    if (!p) {
      p = new Probe(m);
      this.probes.set(m, p);
    }
    return p;
  }

  setFocused(m: string | undefined) {
    const p = m ? this.getProbe(m) : undefined;
    const q = this.focused;
    if (p !== q) {
      this.focused = p;
      this.forceUpdate();
      return;
    }
  }

  //--- Rows

  getRows(): RowProps[] { return []; }

  //--- Force Reload (empty caches)
  forceReload() {

  }

  //--- Force Updating (re-render)
  private age = 0;
  private signal?: callback;

  getAge() { return this.age; }

  bind(age: number, setAge: (a: number) => void) {
    const next = age < 0xFFFF ? 1 + age : 0;
    this.age = age;
    this.signal = () => setAge(next);
    return () => { this.signal = undefined; }
  }

  forceUpdate() {
    const s = this.signal;
    if (s) { this.signal = undefined; s(); }
  }

}

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

interface ProbePanelProps {
  age: number;
  marker: string | undefined;
}

function ProbePanel(props: ProbePanelProps) {
  return (
    <div>MARKER {props.marker ?? '(none)'}@{props.age}</div>
  );
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface ValuesPanelProps {
  marker: string | undefined;
  rows: RowProps[];
}

function ValuesPanel(_props: ValuesPanelProps) {
  return (
    <Vfill>
      <AutoSizer>
        {({ width, height }) => (
          <div style={{ width, height }}>
            SIZE {width} x {height} (W/H)
          </div>
        )}
      </AutoSizer>
    </Vfill>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

// WARNING: MUST HAVE SINGLE USE
function useVState(): VState {
  const vstate = React.useMemo(() => new VState(), [VState]);
  const [age, setAge] = React.useState(0);
  React.useEffect(() => vstate.bind(age, setAge), [age, setAge]);
  Server.useSignal(Values.changed, vstate.forceReload);
  return vstate;
}

function ValuesComponent() {
  const vstate = useVState();
  const [selection] = States.useSelection();
  const marker = selection?.current?.marker;
  return (
    <>
      <TitleBar />
      <Vfill>
        <ProbePanel marker={marker} age={vstate.getAge()} />
        <ValuesPanel marker={marker} rows={vstate.getRows()} />
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
