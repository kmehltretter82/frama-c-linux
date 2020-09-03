// --------------------------------------------------------------------------
// --- Spread Monitoring
// --------------------------------------------------------------------------

/**
   Monitoring data.

   This package allow to collect and consolidate data that are
   collected from different source.

   @packageDocumentation
   @module dome/layout/forms
 */

import { debounce } from 'lodash';
import isEqual from 'react-fast-compare';
import Emitter from 'events';
import React from 'react';

const TRIGGER = 'dome-monitor';

export interface Callback<A> {
  (value: A): void;
}

export class Monitor<A> {
  readonly empty: A;
  readonly merge: (a: A, b: A) => A;
  readonly equal: (a: A, b: A) => boolean;

  private readonly emitter = new Emitter();
  private readonly data: Map<symbol, A> = new Map();
  private value: A;
  private count: number;

  /**
     @param empty - default value
     @param merge - combine the values of two items
        (shall be associative and commutative)
     @param equal - comparison of values
        (defaults to `react-fast-compare`)
     @param delay - debouncing delay
        (defaults to 1ms, use 0 to not debounce at all)
   */
  constructor(
    empty: A,
    merge: (a: A, b: A) => A,
    equal?: (a: A, b: A) => boolean,
    delay?: number,
  ) {
    this.empty = empty;
    this.merge = merge;
    this.value = empty;
    this.equal = equal ?? isEqual;
    this.count = 0;
    if (delay !== 0)
      this.trigger = debounce(this.trigger, delay ?? 1);
  }

  /**
     Returns all registered values, merged.

     Consider using the associated React Hook [[useMonitor]] instead.
   */
  getValue(): A { return this.value; }

  /** Returns true if there is no registered item. */
  isEmpty() { return this.data.size === 0; }

  private trigger() {
    let A = this.empty;
    const N = this.data.size;
    const F = this.merge;
    this.data.forEach((v) => { A = F(A, v); });
    if (N !== this.count || !this.equal(A, this.value)) {
      this.count = N;
      this.value = A;
      this.emitter.emit(TRIGGER, A, N);
    }
  }

  /** Register a callback on (debounced) changes. */
  on(fn: Callback<A>) { this.emitter.on(TRIGGER, fn); }

  /** Register a callback on (debounced) changes. */
  off(fn: Callback<A>) { this.emitter.off(TRIGGER, fn); }

  /**
     Register a new item with its value.
     Consider using the associated React Hook [[useMonitoredItem]] instead.
   */
  addItem(value: A) {
    const item = Symbol('monitored-item');
    this.data.set(item, value);
    this.trigger();
    return item;
  }

  /**
     Unregister an item previously registered with [[addItem]].
     Consider using the associated React Hook [[useMonitoredItem]] instead.
   */
  remove(item: symbol) {
    this.data.delete(item);
    this.trigger();
  }

}

/** Monitor computing the sum of item values. */
export class MonitorSum extends Monitor<number>
{
  constructor() {
    super(0, (a, b) => a + b);
  }
}

/**
   Monitor computing the conjunction of item values.
   The returned value is `true` iff _all_ item values are `true`.
 */
export class MonitorAll extends Monitor<boolean>
{
  constructor() {
    super(true, (a, b) => a && b);
  }
}

/**
   Monitor computing the disjunction of item values.
   The returned value is `false` when _any_ item value is `false`.
 */
export class MonitorAny extends Monitor<boolean>
{
  constructor() {
    super(false, (a, b) => a || b);
  }
}

/* --------------------------------------------------------------------------*/
/* --- Hooks                                                              ---*/
/* --------------------------------------------------------------------------*/

/** Returns the current monitored value. */
export function useMonitor<A>(M: Monitor<A>): A {
  const [value, setValue] = React.useState<A>(M.empty);
  React.useEffect(() => {
    M.on(setValue);
    return () => M.off(setValue);
  }, [M]);
  return value;
}

/** Returns the current monitored value, if defined. */
export function useIfMonitor<A>(M?: Monitor<A>): A | undefined {
  const [value, setValue] = React.useState<A | undefined>();
  React.useEffect(() => {
    if (M) {
      M.on(setValue);
      return () => M.off(setValue);
    }
    setValue(undefined);
    return undefined;

  }, [M]);
  return value;
}

/** Register an item with its associated value (when mounted, if any). */
export function useMonitoredItem<A>(
  M: Monitor<A> | undefined,
  value: A | undefined,
) {
  React.useEffect(() => {
    if (M && value !== undefined) {
      const id = M.addItem(value);
      return () => M.remove(id);
    }
    return undefined;
  }, [M, value]);
}

// --------------------------------------------------------------------------
