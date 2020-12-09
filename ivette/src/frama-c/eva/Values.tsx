// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import { Vfill, Hpack } from 'dome/layout/boxes';
import { Label, Code } from 'dome/controls/labels';

// External Libs
import { debounce } from 'lodash';
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values';

// CSS
import './style.css';

/* --------------------------------------------------------------------------*/
/* --- Utilities                                                          ---*/
/* --------------------------------------------------------------------------*/

type callback = () => void;
interface Size { width: number; height: number }

/* --------------------------------------------------------------------------*/
/* --- Cell Properties                                                    ---*/
/* --------------------------------------------------------------------------*/

type CellProps = Size;

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

const Ka = 'A'.charCodeAt(0);
const Kz = 'Z'.charCodeAt(0);

class Probe {
  marker: Readonly<string>;
  transient = true;

  // labeling
  static La = Ka;
  static Lk = 0;
  static newLabel() {
    const a = Probe.La;
    const k = Probe.Lk;
    const lbl = String.fromCharCode(a);
    if (a < Kz) {
      Probe.La++;
    } else {
      Probe.La = Ka;
      Probe.Lk++;
    }
    return k > 0 ? lbl + k : lbl;
  }

  // the undefined values means not-a-probe
  label?: string;
  code?: string;
  stmt?: string;

  constructor(marker: string) {
    this.marker = marker;
  }

  async requestProbeInfo(): Promise<void> {
    return Server
      .send(Values.getProbeInfo, this.marker)
      .then(({ code, stmt }) => {
        this.code = code;
        this.stmt = stmt;
        this.label = code ? 'Focus' : undefined;
      })
      .catch(() => {
        this.code = '(error)';
      });
  }

}

/* --------------------------------------------------------------------------*/
/* --- Values State                                                       ---*/
/* --------------------------------------------------------------------------*/

class VState {

  constructor() {
    this.forceUpdate = this.forceUpdate.bind(this);
    this.forceLayout = this.forceLayout.bind(this);
    this.forceReload = this.forceReload.bind(this);
    this.setWidth = debounce(this.setWidth.bind(this), 600);
  }

  // --- Probes
  private focused?: Probe;
  private probes = new Map<string, Probe>();

  getProbe(m: string): Probe {
    let p = this.probes.get(m);
    if (!p) {
      p = new Probe(m);
      this.probes.set(m, p);
      p.requestProbeInfo().then(this.forceLayout);
    }
    return p;
  }

  focus(m: string | undefined): Probe | undefined {
    if (m) {
      const p = this.getProbe(m);
      if (p.stmt) this.focused = p;
    }
    return this.focused;
  }

  // --- Rows

  private width = 0;
  private rows?: RowProps[];

  forceLayout() {
    this.rows = undefined;
    this.forceUpdate();
  }

  getRows(): RowProps[] {
    if (this.rows === undefined) {
      this.rows = [];
    }
    return this.rows;
  }

  // Debounced
  setWidth(width: number) {
    if (this.width !== width) {
      this.width = width;
      this.forceUpdate();
    }
  }

  // --- Force Reload (empty caches)
  forceReload() {
    this.probes.forEach((p) => {
      if (p.transient && p !== this.focused) {
        this.probes.delete(p.marker);
      } else {
        p.requestProbeInfo().then(this.forceUpdate);
      }
    });

  }

  // --- Force Updating (re-render)
  private signal?: callback;

  bind(age: number, setAge: (a: number) => void) {
    const next = age < 0xFFFF ? 1 + age : 0;
    this.signal = () => setAge(next);
    return () => { this.signal = undefined; };
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
  age?: number;
  label?: string;
  code?: string;
}

function ProbePanel(props: ProbePanelProps) {
  const { label, code } = props;
  return code ? (
    <Hpack className="eva-probe">
      {label && <Label className="eva-probe-label">{label}:</Label>}
      {code && <Code className="eva-probe-code">{code}</Code>}
    </Hpack>
  ) : null;
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface ValuesPanelProps {
  age: number;
  vstate: VState;
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
function useVState(): [number, VState] {
  const vstate = React.useMemo(() => new VState(), []);
  const [age, setAge] = React.useState(0);
  React.useEffect(() => vstate.bind(age, setAge), [vstate, age, setAge]);
  Server.useSignal(Values.changed, vstate.forceReload);
  return [age, vstate];
}

function ValuesComponent() {
  const [age, vstate] = useVState();
  const [selection] = States.useSelection();
  const marker = selection?.current?.marker;
  const probe = vstate.focus(marker);
  return (
    <>
      <TitleBar />
      <Vfill>
        <ProbePanel
          key="probe"
          label={probe?.label}
          code={probe?.code}
        />
        <ValuesPanel key="values" age={age} vstate={vstate} />
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
