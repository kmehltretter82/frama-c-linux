// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// External Libs
import { debounce } from 'lodash';
import equal from 'react-fast-compare';

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

/* --------------------------------------------------------------------------*/
/* --- Row Properties                                                     ---*/
/* --------------------------------------------------------------------------*/

export type RowKind = 'probes' | 'values' | 'callstack';

export class Row {

  key: string;
  kind: RowKind;
  height = 0;

  constructor(kind: RowKind, key: string) {
    this.key = key;
    this.kind = kind;
  }

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
  readonly marker: string;
  forceUpdate: callback;
  forceLayout: callback;
  transient = true;
  label?: string;
  code?: string;
  stmt?: string;
  rank?: number;

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
      .then(({ code, stmt, rank }) => {
        this.code = code;
        this.stmt = stmt;
        this.rank = rank;
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
/* --- Layout Algorithm                                                   ---*/
/* --------------------------------------------------------------------------*/

export interface LayoutProps {
  zoom?: number;
  width?: number;
}

class LayoutEngine {

  // --- Setup

  /* private */ readonly zoom: number;
  /* private */ readonly width: number;
  private readonly rows: Row[] = [];
  constructor(props?: LayoutProps) {
    this.zoom = props?.zoom ?? 0;
    this.width = props?.width ?? 0;
  }

  // --- Final Rows

  flush() { return this.rows; }

}

/* --------------------------------------------------------------------------*/
/* --- Values State                                                       ---*/
/* --------------------------------------------------------------------------*/

export class VState implements StateCallbacks {

  constructor() {
    this.forceUpdate = this.forceUpdate.bind(this);
    this.forceLayout = this.forceLayout.bind(this);
    this.forceReload = this.forceReload.bind(this);
    this.computeLayout = this.computeLayout.bind(this);
    this.setLayout = debounce(this.setLayout.bind(this), 600);
    this.getRowKey = this.getRowKey.bind(this);
    this.getRowHeight = this.getRowHeight.bind(this);
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

  private forcedLayout = false;
  private layout?: LayoutProps;
  private rows: Row[] = [];

  forceLayout() {
    if (!this.forcedLayout) {
      this.forcedLayout = true;
      setImmediate(this.computeLayout);
    }
  }

  private computeLayout() {
    const engine = new LayoutEngine(this.layout);
    this.forcedLayout = false;
    this.rows = engine.flush();
    this.forceUpdate();
  }

  getRowCount() {
    return this.rows.length;
  }

  getRowKey(index: number): string {
    const row = this.rows[index];
    return row ? row.key : `#${index}`;
  }

  getRowHeight(index: number): number {
    const row = this.rows[index];
    return row ? row.height : 0;
  }

  // --- Debounced
  setLayout(ly?: LayoutProps) {
    if (!equal(this.layout, ly)) {
      this.layout = ly;
      this.forceLayout();
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
