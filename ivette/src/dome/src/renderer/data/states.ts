// --------------------------------------------------------------------------
// --- States
// --------------------------------------------------------------------------

/**
   Typed States & Settings
   @package dome/data/states
*/

import React from 'react';
import isEqual from 'react-fast-compare';
import * as Dome from 'dome';

export type NonFunction =
  undefined | null | boolean | number | string | object | any[] | bigint | symbol;

/** State updater. `undefined` is no-op, `null` is reset, new value,
    or updating function applied to the current, lastly updated value. */
export type updateAction<A extends NonFunction> =
  undefined | null | A | ((current: A) => A);

/** The type of updater callbacks. Typically used for `[A,setState<A>]` hooks. */
export type setState<A extends NonFunction> = (action: updateAction<A>) => void;

/** Base state interface. */
export interface State<A extends NonFunction> {
  readonly get: () => A;
  readonly set: (value: A) => void;
  readonly update: setState<A>;
  on(callback: (value: A) => void): void;
  off(callback: (value: A) => void): void;
}

/** React Hook, similar to `React.useState()`. */
export function useState<A extends NonFunction>(s: State<A>): [A, setState<A>] {
  const [current, setCurrent] = React.useState<A>(s.get);
  React.useEffect(() => {
    s.on(setCurrent);
    return () => s.off(setCurrent);
  });
  return [current, s.update];
};

/**
   State with initial default value.
 */
export class StateDef<A extends NonFunction> implements State<A> {
  protected value: A;
  protected defaultValue: A;
  protected event: symbol;

  constructor(defaultValue: A) {
    this.value = this.defaultValue = defaultValue;
    this.event = Symbol('dome.state');
    this.get = this.get.bind(this);
    this.set = this.get.bind(this);
    this.reset = this.reset.bind(this);
    this.update = this.update.bind(this);
  }

  get(): A { return this.value; }

  /** Notify callbacks on change, using _deep_ structural comparison. */
  set(value: A) {
    if (!isEqual(value, this.value)) {
      this.value = value;
      Dome.emit(this.event, value);
    }
  }

  /** State updater. */
  update(upd: updateAction<A>) {
    if (upd === undefined) return;
    if (upd === null) { this.reset(); return; }
    if (typeof upd === 'function') this.set(upd(this.value));
  }

  /** Restore default value. */
  reset() {
    this.set(this.defaultValue);
  }

  /** Callback Emitter. */
  on(callback: (value: A) => void) {
    Dome.emitter.on(this.event, callback);
  }

  /** Callback Emitter. */
  off(callback: (value: A) => void) {
    Dome.emitter.off(this.event, callback);
  }

}

/**
   State with possibly undefined initial value.
 */
export class StateOpt<A extends NonFunction> extends StateDef<undefined | A> {
  constructor(defaultValue?: A) {
    super(defaultValue);
  }
}

// --------------------------------------------------------------------------
