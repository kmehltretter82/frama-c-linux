// --------------------------------------------------------------------------
// --- Cells
// --------------------------------------------------------------------------

// Frama-C
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/api/kernel/ast';
import * as Values from 'frama-c/api/plugins/eva/values';

// --------------------------------------------------------------------------
// --- Cell Utilities
// --------------------------------------------------------------------------

export type callback = () => void;

export interface ModelCallbacks {
  forceUpdate: callback;
  forceLayout: callback;
}

export interface Size { cols: number; rows: number }

export const EMPTY: Size = { cols: 0, rows: 0 };

export function sizeof(text?: string): Size {
  if (!text) return EMPTY;
  const lines = text.split('\n');
  return {
    rows: lines.length,
    cols: lines.reduce((w, l) => Math.max(w, l.length), 0),
  };
}

export function merge(a: Size, b: Size): Size {
  return {
    cols: Math.max(a.cols, b.cols),
    rows: Math.max(a.rows, b.rows),
  };
}

export function addH(a: Size, b: Size, padding = 0): Size {
  return {
    cols: a.cols + b.cols + padding,
    rows: Math.max(a.rows, b.rows),
  };
}

export function addV(a: Size, b: Size, padding = 0): Size {
  return {
    cols: Math.max(a.cols, b.cols),
    rows: a.rows + b.rows + padding,
  };
}

export function addS(s: Size, t: string | undefined): Size {
  return t ? merge(s, sizeof(t)) : s;
}

export function lt(a: Size, b: Size): boolean {
  return a.rows < b.rows && a.cols < b.cols;
}

export function leq(a: Size, b: Size): boolean {
  return a.rows <= b.rows && a.cols <= b.cols;
}

// --------------------------------------------------------------------------
// --- Data
// --------------------------------------------------------------------------

export type EvaStatus = 'True' | 'False' | 'Unknown';
export type EvaAlarm = [EvaStatus, string];
export type EvaState = 'Here' | 'After' | 'Then' | 'Else';

export interface EvaValues {
  errors?: string;
  values?: string;
  v_after?: string;
  v_then?: string;
  v_else?: string;
  alarms?: EvaAlarm[];
  size: Size;
}

export function valueAt(v: EvaValues, st: EvaState): string | undefined {
  switch (st) {
    case 'Here': return v.values;
    case 'After': return v.v_after;
    case 'Then': return v.v_then;
    case 'Else': return v.v_else;
    default: return undefined;
  }
}

// --------------------------------------------------------------------------
// --- Value Cache
// --------------------------------------------------------------------------

export class ValueCache {

  private readonly state: ModelCallbacks;
  private readonly probes = new Map<Ast.marker, Size>(); // Marker -> max in column
  private readonly stacks = new Map<string, Size>(); // Callstack -> max in row
  private readonly vcache = new Map<string, EvaValues>(); // '<Marker><@Callstack>?' -> value
  private smax = EMPTY; // max cell size

  constructor(state: ModelCallbacks) {
    this.state = state;
  }

  clear() {
    this.smax = EMPTY;
    this.probes.clear();
    this.stacks.clear();
    this.vcache.clear();
    this.state.forceLayout();
  }

  // --- Cached Measures

  getMaxSize() { return this.smax; }

  getProbeSize(target: Ast.marker) {
    return this.probes.get(target) ?? EMPTY;
  }

  private static stackKey(stmt: string, callstack: Values.callstack) {
    return `${stmt}::${callstack}`;
  }

  getStackSize(stmt: string, callstack: Values.callstack) {
    const key = ValueCache.stackKey(stmt, callstack);
    return this.stacks.get(key) ?? EMPTY;
  }

  // --- Cached Values & Request Update

  getValues(
    target: Ast.marker,
    stmt: string | undefined,
    callstack: Values.callstack | undefined,
  ): EvaValues {
    const key = callstack !== undefined ? `${target}@${callstack}` : target;
    const cache = this.vcache;
    const cached = cache.get(key);
    if (cached) return cached;
    const newValue: EvaValues = { values: '', size: EMPTY };
    if (callstack !== undefined && stmt === undefined)
      return newValue;
    // callstack !== undefined ==> stmt !== undefined)
    cache.set(key, newValue);
    Server
      .send(Values.getValues, { target, callstack })
      .then((r) => {
        newValue.errors = undefined;
        newValue.values = r.values;
        newValue.v_after = r.v_after;
        newValue.v_then = r.v_then;
        newValue.v_else = r.v_else;
        newValue.alarms = r.alarms;
        if (this.updateLayout(target, stmt, callstack, newValue))
          this.state.forceLayout();
        else
          this.state.forceUpdate();
      })
      .catch((err) => {
        newValue.errors = `$Error: ${err}`;
        this.state.forceUpdate();
      });
    return newValue;
  }

  // --- Updating Measures

  private updateLayout(
    target: Ast.marker,
    stmt: string | undefined,
    callstack: Values.callstack | undefined,
    v: EvaValues,
  ): boolean {
    // measuring cell
    let s = sizeof(v.values);
    s = addS(s, v.v_after);
    s = addS(s, v.v_then);
    s = addS(s, v.v_else);
    v.size = s;
    // max cell size
    const { smax } = this;
    let small = leq(s, smax);
    if (!small) this.smax = merge(s, smax);
    // max size for probe column
    const ps = this.getProbeSize(target);
    if (!leq(s, ps)) {
      this.probes.set(target, merge(ps, s));
      small = false;
    }
    // max size for stack row
    if (callstack !== undefined) {
      if (stmt === undefined) small = false;
      else {
        const key = ValueCache.stackKey(stmt, callstack);
        const cs = this.stacks.get(key) ?? EMPTY;
        if (!leq(s, cs)) {
          this.stacks.set(key, merge(cs, s));
          small = false;
        }
      }
    }
    // request new layout if not small enough
    return !small;
  }

}

// --------------------------------------------------------------------------
