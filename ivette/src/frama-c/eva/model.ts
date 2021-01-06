// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// External Libs
import { throttle } from 'lodash';
import equal from 'react-fast-compare';
import * as Dome from 'dome';

import * as Server from 'frama-c/server';
import * as Values from 'frama-c/api/plugins/eva/values';
import * as Ast from 'frama-c/api/kernel/ast';

// Model
import { Probe } from './probes';
import { StacksCache, Callsite } from './stacks';
import { ModelCallbacks, ValueCache, EvaState } from './cells';
import { LayoutProps, LayoutEngine, Row } from './layout';

export interface ModelLayout extends LayoutProps {
  fct?: string;
  marker?: Ast.marker;
}

/* --------------------------------------------------------------------------*/
/* --- EVA Values Model                                                   ---*/
/* --------------------------------------------------------------------------*/

export class Model implements ModelCallbacks {

  constructor() {
    this.forceUpdate = this.forceUpdate.bind(this);
    this.forceLayout = this.forceLayout.bind(this);
    this.forceReload = this.forceReload.bind(this);
    this.computeLayout = this.computeLayout.bind(this);
    this.setLayout = throttle(this.setLayout.bind(this), 300);
    this.getRowKey = this.getRowKey.bind(this);
    this.getRowCount = this.getRowCount.bind(this);
    this.getRowLines = this.getRowLines.bind(this);
    Server.onSignal(Values.changed, this.forceReload);
    Server.onShutdown(this.forceReload);
  }

  // --- Probes

  private vstmt: EvaState = 'After';
  private vcond: EvaState = 'Here';
  private selected?: Probe;
  private focused?: Probe;
  private callstack?: Values.callstack;
  private remanent?: Probe; // last transient
  private probes = new Map<string, Probe>();

  getFocused() { return this.focused; }
  isFocused(p: Probe | undefined) { return this.focused === p; }

  getProbe(fct: string, m: Ast.marker): Probe {
    let p = this.probes.get(m);
    if (!p) {
      p = new Probe(this, fct, m);
      this.probes.set(m, p);
      p.requestProbeInfo();
    }
    return p;
  }

  getStacks(p: Probe | undefined): Values.callstack[] {
    return p ? this.stacks.getStacks(p.marker) : [];
  }

  getVstmt(): EvaState { return this.vstmt; }
  getVcond(): EvaState { return this.vcond; }
  setVstmt(s: EvaState) { this.vstmt = s; this.forceUpdate(); }
  setVcond(s: EvaState) { this.vcond = s; this.forceUpdate(); }

  // --- Caches

  readonly stacks = new StacksCache(this);
  readonly values = new ValueCache(this);

  // --- Rows

  private lock = false;
  private layout: ModelLayout = { margin: 80 };
  private rows: Row[] = [];

  getRow(index: number): Row | undefined {
    return this.rows[index];
  }

  getRowCount() {
    return this.rows.length;
  }

  getRowKey(index: number): string {
    const row = this.rows[index];
    return row ? row.key : `#${index}`;
  }

  getRowLines(index: number): number {
    const row = this.rows[index];
    return row ? row.hlines : 0;
  }

  setSelectedRow(row: Row) {
    const cs = row.callstack;
    if (cs !== this.callstack) {
      this.callstack = cs;
      this.forceUpdate();
    }
  }

  isSelectedRow(row: Row): boolean {
    const cs = this.callstack;
    return cs !== undefined && cs === row.callstack;
  }

  isAlignedRow(row: Row): boolean {
    const cs = this.callstack;
    const cr = row.callstack;
    return cs !== undefined && cr !== undefined && this.stacks.aligned(cs, cr);
  }

  getCallstack(): Values.callstack | undefined {
    return this.callstack;
  }

  getCalls(): Callsite[] {
    const c = this.callstack;
    return c === undefined ? [] : this.stacks.getCalls(c);
  }

  // --- Throttled
  setLayout(ly: ModelLayout) {
    if (!equal(this.layout, ly)) {
      this.layout = ly;
      const { fct, marker } = ly;
      this.selected =
        fct && marker ? this.getProbe(fct, marker) : undefined;
      this.forceLayout();
    }
  }

  // --- Recompute Layout

  private computeLayout() {
    if (this.lock) return;
    this.lock = true;
    const s = this.selected;
    if (!s) {
      this.focused = undefined;
      this.remanent = undefined;
    } else if (!s.loading) {
      this.focused = s;
      if (s.code && s.transient) {
        this.remanent = s;
      } else {
        this.remanent = undefined;
      }
    }
    const toLayout: Probe[] = [];
    this.probes.forEach((p) => {
      if (p.code && (!p.transient || p === this.remanent)) {
        toLayout.push(p);
      }
    });
    const engine = new LayoutEngine(
      this.layout,
      this.values,
      this.stacks,
    );
    this.rows = engine.layout(toLayout);
    this.laidout.emit();
    this.lock = false;
  }

  // --- Force Reload (empty caches)
  forceReload() {
    this.focused = undefined;
    this.remanent = undefined;
    this.selected = undefined;
    this.callstack = undefined;
    this.probes.clear();
    this.stacks.clear();
    this.values.clear();
    this.forceLayout();
    this.forceUpdate();
  }

  // --- Events
  readonly changed = new Dome.Event('eva-changed');
  readonly laidout = new Dome.Event('eva-laidout');

  // --- Force Layout
  forceLayout() {
    setImmediate(this.computeLayout);
  }

  // --- Foce Update
  forceUpdate() { this.changed.emit(); }

}

// --------------------------------------------------------------------------
// --- EVA Model
// --------------------------------------------------------------------------

let MODEL: Model | undefined;

export function getModelInstance(): Model {
  if (!MODEL) MODEL = new Model();
  return MODEL;
}

// --------------------------------------------------------------------------
