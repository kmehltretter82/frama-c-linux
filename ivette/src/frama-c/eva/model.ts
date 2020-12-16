// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// External Libs
import { throttle } from 'lodash';
import equal from 'react-fast-compare';

import type { marker } from 'frama-c/api/kernel/ast';

// Model
import { Probe } from './probes';
import { callback, StateCallbacks, ValueCache } from './cells';
import { LayoutProps, LayoutEngine, Row } from './layout';

/* --------------------------------------------------------------------------*/
/* --- EVA Values Model                                                   ---*/
/* --------------------------------------------------------------------------*/

export class Model implements StateCallbacks {

  constructor(forceUpdate: callback) {
    this.forceUpdate = forceUpdate;
    this.forceLayout = this.forceLayout.bind(this);
    this.forceReload = this.forceReload.bind(this);
    this.computeLayout = this.computeLayout.bind(this);
    this.setLayout = throttle(this.setLayout.bind(this), 300);
    this.getRowKey = this.getRowKey.bind(this);
    this.getRowCount = this.getRowCount.bind(this);
    this.getRowHeight = this.getRowHeight.bind(this);
  }

  // --- Probes

  private focused?: Probe;
  private remanent?: Probe; // last transient
  private probes = new Map<string, Probe>();

  isFocused(p: Probe | undefined) { return p === this.focused; }

  getProbe(m: marker): Probe {
    let p = this.probes.get(m);
    if (!p) {
      p = new Probe(this, m);
      this.probes.set(m, p);
      p.requestProbeInfo();
    }
    return p;
  }

  focus(m: marker | undefined): Probe | undefined {
    const r = this.remanent;
    if (m) {
      const p = this.getProbe(m);
      if (p.stmt) {
        this.focused = p;
        if (p.transient && p !== r) {
          this.remanent = p;
          this.forceLayout();
        } else {
          this.forceUpdate();
        }
      } else {
        this.focused = undefined;
        this.remanent = undefined;
        this.forceLayout();
      }
    }
    return this.focused;
  }

  // --- Values

  readonly cache = new ValueCache(this);

  // --- Rows

  private forcedLayout = false;
  private layout: LayoutProps = { margin: 80 };
  private rows: Row[] = [];

  forceLayout() {
    if (!this.forcedLayout) {
      this.forcedLayout = true;
      setImmediate(this.computeLayout);
    }
  }

  private computeLayout() {
    this.forcedLayout = false;
    const toLayout: Probe[] = [];
    this.probes.forEach((p) => {
      if (p.code && (!p.transient || p === this.remanent)) {
        toLayout.push(p);
      }
    });
    const engine = new LayoutEngine(this.cache, this.layout);
    toLayout.sort(Probe.order).forEach(engine.push);
    this.rows = engine.flush();
    this.forceUpdate();
  }

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

  getRowHeight(index: number): number {
    const row = this.rows[index];
    return row ? row.height : 0;
  }

  // --- Throttled
  setLayout(ly: LayoutProps, forceGridLayout: callback) {
    if (!equal(this.layout, ly)) {
      this.layout = ly;
      this.forceLayout();
      forceGridLayout();
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
    this.cache.clear();
    this.forceLayout();
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
