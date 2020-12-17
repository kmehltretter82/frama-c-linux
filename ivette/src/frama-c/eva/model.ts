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
import { StacksCache } from './stacks';
import { StateCallbacks, ValueCache } from './cells';
import { LayoutProps, LayoutEngine, Row } from './layout';

export interface ModelLayout extends LayoutProps {
  target?: Ast.marker;
}

/* --------------------------------------------------------------------------*/
/* --- EVA Values Model                                                   ---*/
/* --------------------------------------------------------------------------*/

export class Model implements StateCallbacks {

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
  }

  // --- Probes

  private selected?: Probe;
  private focused?: Probe;
  private remanent?: Probe; // last transient
  private probes = new Map<string, Probe>();

  getFocused() { return this.focused; }
  isFocused(p: Probe | undefined) { return this.focused === p; }
  isRemanent(p: Probe | undefined) { return this.remanent === p; }

  getProbe(m: Ast.marker): Probe {
    let p = this.probes.get(m);
    if (!p) {
      p = new Probe(this, m);
      this.probes.set(m, p);
      p.requestProbeInfo();
    }
    return p;
  }

  getStacks(p: Probe | undefined): Values.callstack[] {
    const stmt = p?.stmt;
    return stmt ? this.stacks.getStacks(stmt) : [];
  }

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

  // --- Throttled
  setLayout(ly: ModelLayout) {
    if (!equal(this.layout, ly)) {
      this.layout = ly;
      const target = Ast.jMarker(ly.target);
      this.selected = target ? this.getProbe(target) : undefined;
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
    } else if (s.loading) {
      this.focused = undefined;
    } else {
      this.focused = s;
      if (s.code) {
        if (s.transient) this.remanent = s;
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
    toLayout.sort(Probe.order).forEach(engine.push);
    this.rows = engine.flush();
    this.laidout.emit();
    this.lock = false;
  }

  // --- Force Reload (empty caches)
  forceReload() {
    this.focused = undefined;
    this.remanent = undefined;
    this.selected = undefined;
    this.probes.clear();
    this.stacks.clear();
    this.values.clear();
    this.forceLayout();
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
