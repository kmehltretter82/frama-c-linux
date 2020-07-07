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
import { DEVEL } from 'dome/misc/system';
import * as Dome from 'dome';
import * as JSON from './json';

const UPDATE = 'dome.states.update';

/** State interface. */
export type State<A> = [A, (update: A) => void];

/** State field of an object state. */
export function key<A, K extends keyof A>(
  state: State<A>,
  key: K,
): State<A[K]> {
  const [props, setProps] = state;
  return [props[key], (value: A[K]) => {
    const newProps = Object.assign({}, props);
    newProps[key] = value;
    setProps(newProps);
  }];
}

/** State index of an array state. */
export function index<A>(
  state: State<A[]>,
  index: number,
): State<A> {
  const [array, setArray] = state;
  return [array[index], (value: A) => {
    const newArray = array.slice();
    newArray[index] = value;
    setArray(newArray);
  }];
}

/** Log state updates in the console. */
export function debug<A>(msg: string, st: State<A>): State<A> {
  const [value, setValue] = st;
  return [value, (v) => { console.log(msg, v); setValue(v); }];
}

/** Purely local value. No hook, no events, just a ref. */
export function local<A>(init: A): State<A> {
  const ref = { current: init };
  return [ref.current, (v) => ref.current = v];
}

/** Cross-component State. */
export class GlobalState<A> {

  private value: A;
  private emitter: Emitter;

  constructor(initValue: A) {
    this.value = initValue;
    this.emitter = new Emitter;
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

/** React Hook, similar to `React.useState()`.
    Assignments to the global state also update _all_
    its associated hooks and listeners. */
export function useGlobalState<A>(s: GlobalState<A>): State<A> {
  const [current, setCurrent] = React.useState<A>(s.getValue);
  React.useEffect(() => {
    s.on(setCurrent);
    return () => s.off(setCurrent);
  });
  return [current, s.setValue];
};

// --------------------------------------------------------------------------
// --- Settings
// --------------------------------------------------------------------------

/**
   Generic interface to Window and Global Settings.
   To be used with [[useSettings]] with instances of its derived classes,
   typically [[WindowSettings]] and [[GlobalSettings]]. You should never have
   to implement a Settings class on your own.

   All setting values are identified with
   an untyped `dataKey: string`, that can be dynamically modified
   for each component. Hence, two components might share both datakeys
   and settings.

   When several components share the same setting `dataKey` the behavior will be
   different depending on the situation:
   - for Window Settings, each component in each window retains its own
   setting value, although the last modified value from _any_ of them will be
   saved and used for any further initial value;
   - for Global Settings, all components synchronize to the last modified value
   from any component of any window.

   Type safety is ensured by safe JSON encoders and decoders, however, they
   might fail at runtime, causing settings value to be initialized to their
   fallback and not to be saved nor synchronized.
   This is not harmful but annoying.

   To mitigate this effect, each instance of a Settings class has its
   own, private, unique symbol that we call its « role ». A given `dataKey`
   shall always be used with the same « role » otherwise it is discarded,
   and an error message is logged when in DEVEL mode.
 */
export abstract class Settings<A> {

  private static keyRoles = new Map<string, symbol>();

  private readonly role: symbol;
  protected readonly decoder: JSON.Safe<A>;
  protected readonly encoder: JSON.Encoder<A>;

  /**
     Encoders shall be protected against exception.
     Use [[dome/data/json.jTry]] and [[dome/data/json.jCatch]] in case of uncertainty.
     Decoders are automatically protected internally to the Settings class.
     @param role Debugging name of instance roles (each instance has its unique
     role, though)
     @param decoder JSON decoder for the setting values
     @param encoder JSON encoder for the setting values
     @param fallback If provided, used to automatically protect your encoders
     against exceptions.
   */
  constructor(
    role: string,
    decoder: JSON.Safe<A>,
    encoder: JSON.Encoder<A>,
    fallback?: A,
  ) {
    this.role = Symbol(role);
    this.encoder = encoder;
    this.decoder =
      fallback !== undefined ? JSON.jCatch(decoder, fallback) : decoder;
  }

  /**
     Returns identity if the data key is only
     used with the same setting instance.
     Otherwise, returns `undefined`.
   */
  validateKey(dataKey?: string): string | undefined {
    if (dataKey === undefined) return undefined;
    const rq = this.role;
    const rk = Settings.keyRoles.get(dataKey);
    if (rk === undefined) {
      Settings.keyRoles.set(dataKey, rq);
    } else {
      if (rk !== rq) {
        if (DEVEL) console.error(
          `[Dome.settings] Key ${dataKey} used with incompatible roles`, rk, rq,
        );
        return undefined;
      }
    }
    return dataKey;
  }

  /** @internal */
  abstract loadData(key: string): JSON.json;

  /** @internal */
  abstract saveData(key: string, data: JSON.json): void;

  /** @internal */
  abstract event: string;

  /** Returns the current setting value for the provided data key. You shall
      only use validated keys otherwise you might fallback to default values. */
  loadValue(dataKey?: string) {
    return this.decoder(dataKey ? this.loadData(dataKey) : undefined)
  }

  /** Push the new setting value for the provided data key.
      You shall only use validated keys otherwise further loads
      might fail and fallback to defaults. */
  saveValue(dataKey: string, value: A) {
    try { this.saveData(dataKey, this.encoder(value)); }
    catch (err) {
      if (DEVEL) console.error(
        '[Dome.settings] Error while encoding value',
        dataKey, value, err,
      );
    }
  }

}

/**
   Generic React Hook to be used with any kind of [[Settings]].
   You may share `dataKey` between components, or change it dynamically.
   However, a given data key shall always be used for the same Setting instance.
   See [[Settings]] documentation for details.
   @param S The instance settings to be used.
   @param dataKey Identifies which value in the settings to be used.
 */
export function useSettings<A>(
  S: Settings<A>,
  dataKey?: string,
): [A, (update: A) => void] {

  const theKey = React.useMemo(() => S.validateKey(dataKey), [S, dataKey]);
  const [value, setValue] = React.useState<A>(() => S.loadValue(theKey));

  React.useEffect(() => {
    if (theKey) {
      const callback = () => setValue(S.loadValue(theKey));
      Dome.on(S.event, callback);
      return () => Dome.off(S.event, callback);
    }
    return undefined;
  });

  const updateValue = React.useCallback((update: A) => {
    if (!isEqual(value, update)) {
      setValue(update);
      if (theKey) S.saveValue(theKey, update);
    }
  }, [S, theKey]);

  return [value, updateValue];

}

/** Window Settings for non-JSON data.
    In most situations, you can use [[WindowSettings]] instead.
    You can use a [[dome/data/json.Loose]] decoder for optional values. */
export class WindowSettingsData<A> extends Settings<A> {

  constructor(
    role: string,
    decoder: JSON.Safe<A>,
    encoder: JSON.Encoder<A>,
    fallback?: A,
  ) {
    super(role, decoder, encoder, fallback);
  }

  event = 'dome.defaults';
  loadData(key: string) { return Dome.getWindowSetting(key) as JSON.json; }
  saveData(key: string, data: JSON.json) { Dome.setWindowSetting(key, data); }

}

/** Global Settings for non-JSON data.
    In most situations, you can use [[WindowSettings]] instead.
    You can use a [[dome/data/json.Loose]] decoder for optional values. */
export class GlobalSettingsData<A> extends Settings<A> {

  constructor(
    role: string,
    decoder: JSON.Safe<A>,
    encoder: JSON.Encoder<A>,
    fallback?: A,
  ) {
    super(role, decoder, encoder, fallback);
  }

  event = 'dome.settings';
  loadData(key: string) { return Dome.getGlobalSetting(key) as JSON.json; }
  saveData(key: string, data: JSON.json) { Dome.setGlobalSetting(key, data); }

}

/** Window Settings.
    For non-JSON data, use [[WindowSettingsData]] instead.
    You can use a [[dome/data/json.Loose]] decoder for optional values. */
export class WindowSettings<A extends JSON.json> extends WindowSettingsData<A> {

  constructor(role: string, decoder: JSON.Safe<A>, fallback?: A) {
    super(role, decoder, JSON.identity, fallback);
  }

}

/** Global Settings.
    For non-JSON data, use [[WindowSettingsData]] instead.
    You can use a [[dome/data/json.Loose]] decoder for optional values. */
export class GlobalSettings<A extends JSON.json> extends GlobalSettingsData<A> {

  constructor(role: string, decoder: JSON.Safe<A>, fallback?: A) {
    super(role, decoder, JSON.identity, fallback);
  }

}

// --------------------------------------------------------------------------
