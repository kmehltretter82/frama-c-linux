// --------------------------------------------------------------------------
// --- States
// --------------------------------------------------------------------------

/**
   Typed States & Settings
   @packageDocumentation
   @module dome/data/states
*/

import React from 'react';
import Emitter from 'events';
import isEqual from 'react-fast-compare';

const UPDATE = 'dome.states.update';

/** Cross-component State. */
export class State<A> {

  private value: A;
  private emitter: Emitter;

  constructor(initValue: A) {
    this.value = initValue;
    this.emitter = new Emitter();
    this.getValue = this.getValue.bind(this);
    this.setValue = this.setValue.bind(this);
  }

  /** Current state value. */
  getValue() { return this.value; }

  /** Notify callbacks on change, using _deep_ structural comparison. */
  setValue(value: A) {
    if (!isEqual(value, this.value)) {
      this.value = value;
      this.emitter.emit(UPDATE, value);
    }
  }

  /** Callback Emitter. */
  on(callback: (value: A) => void) {
    this.emitter.on(UPDATE, callback);
  }

  /** Callback Emitter. */
  off(callback: (value: A) => void) {
    this.emitter.off(UPDATE, callback);
  }

}

/** React Hook, similar to `React.useState()`. */
export function useState<A>(s: State<A>): [A, (update: A) => void] {
  const [current, setCurrent] = React.useState<A>(s.getValue);
  React.useEffect(() => {
    s.on(setCurrent);
    return () => s.off(setCurrent);
  }, [s]);
  return [current, s.setValue];
}

// --------------------------------------------------------------------------
