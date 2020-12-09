// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// External Libs
import { debounce } from 'lodash';

// Frama-C
import * as Server from 'frama-c/server';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values';

/* --------------------------------------------------------------------------*/
/* --- Utilities                                                          ---*/
/* --------------------------------------------------------------------------*/

export type callback = () => void;

export interface StateCallbacks {
  forceUpdate: callback;
  forceLayout: callback;
}

export interface Size { width: number; height: number }

/* --------------------------------------------------------------------------*/
/* --- Cell Properties                                                    ---*/
/* --------------------------------------------------------------------------*/

type CellProps = Size;

/* --------------------------------------------------------------------------*/
/* --- Row Properties                                                     ---*/
/* --------------------------------------------------------------------------*/

export type RowKind = 'probes' | 'values' | 'callstack';

interface RowProps extends Size {
  kind: RowKind;
  cells: CellProps[];
}

/* --------------------------------------------------------------------------*/
/* --- Probe Labelling                                                    ---*/
/* --------------------------------------------------------------------------*/

const Ka = 'A'.charCodeAt(0);
const Kz = 'Z'.charCodeAt(0);
const LabelSize = 6;
const LabelRing: string[] = [];
let La = Ka;
let Lk = 0;

function newLabel() {
  let lbl = LabelRing.shift();
  if (lbl) return lbl;
  const a = La;
  const k = Lk;
  lbl = String.fromCharCode(a);
  if (a < Kz) {
    La++;
  } else {
    La = Ka;
    Lk++;
  }
  return k > 0 ? lbl + k : lbl;
}

/* --------------------------------------------------------------------------*/
/* --- Probe State                                                        ---*/
/* --------------------------------------------------------------------------*/

export class Probe implements StateCallbacks {

  // properties
  marker: Readonly<string>;
  forceUpdate: callback;
  forceLayout: callback;
  transient = true;
  label?: string;
  code?: string;
  stmt?: string;

  constructor(marker: string, state: StateCallbacks) {
    this.marker = marker;
    this.forceUpdate = state.forceUpdate;
    this.forceLayout = state.forceLayout;
    this.requestProbeInfo = this.requestProbeInfo.bind(this);
    this.setPersistent = this.setPersistent.bind(this);
    this.setTransient = this.setTransient.bind(this);
  }

  requestProbeInfo() {
    Server
      .send(Values.getProbeInfo, this.marker)
      .then(({ code, stmt }) => {
        this.code = code;
        this.stmt = stmt;
      })
      .catch(() => {
        this.code = '(error)';
      })
      .finally(this.forceUpdate);
  }

  setPersistent() {
    if (this.transient && this.code) {
      this.transient = false;
      if (this.code.length > LabelSize)
        this.label = newLabel();
      this.forceLayout();
    }
  }

  setTransient() {
    if (!this.transient) {
      this.transient = true;
      if (this.label) {
        LabelRing.push(this.label);
        this.label = undefined;
      }
      this.forceLayout();
    }
  }

}

/* --------------------------------------------------------------------------*/
/* --- Values State                                                       ---*/
/* --------------------------------------------------------------------------*/

export class VState implements StateCallbacks {

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
      p = new Probe(m, this);
      this.probes.set(m, p);
      p.requestProbeInfo();
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
        p.requestProbeInfo();
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
