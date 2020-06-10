// --------------------------------------------------------------------------
// --- States
// --------------------------------------------------------------------------

/**
   Typed States & Settings
   @packageDocumentation
   @package dome/data/states
*/

import React from 'react';
import isEqual from 'react-fast-compare';
import { DEVEL } from 'dome/misc/system';
import * as Dome from 'dome';
import * as JSON from './json';

export type NonFunction =
  undefined | null | boolean | number | string | object | any[] | bigint | symbol;

/** State updater. New value or updating function applied to the current,
    lastly updated value. Use `null` to restore default value. */
export type updateAction<A extends NonFunction> =
  null | A | ((current: A) => A);

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
    if (upd === null)
      this.reset();
    else {
      if (typeof upd === 'function')
        this.set(upd(this.value));
      else
        this.set(upd);
    }
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
   setting value, although the last modified value from _any_ of them will be saved
   and used for any further initial value;
   - for Global Settings, all components synchronize to the last modified value
   from any component of any window.

   Type safety is ensured by safe JSON encoders and decoders, however, they
   might fail at runtime, causing settings value to be initialized to their
   fallback and not to be saved or synchronized. This is not harmfull but annoying.

   To mitigate this effect, each instance of a Settings class has its
   own, private, unique symbol that we call its « role ». A given `dataKey`
   shall always be used with the same « role » otherwized it is discarded,
   and an error message is logged when in DEVEL mode.
 */
abstract class Settings<A> {

  private static keyRoles = new Map<string, symbol>();

  private readonly role: symbol;
  protected readonly decoder: JSON.Safe<A>;
  protected readonly encoder: JSON.Encoder<A>;

  /**
     @param role - Debugging name of instance roles (each instance has its unique role, though)
     @param decoder - JSON decoder for the setting values
     @param encoder - JSON encoder for the setting values
   */
  constructor(role: string, decoder: JSON.Safe<A>, encoder: JSON.Encoder<A>) {
    this.role = Symbol(role);
    this.decoder = decoder;
    this.encoder = encoder;
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
          `[Dome.settings] key ${dataKey} used with incompatible roles`, rk, rq,
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
  abstract event: symbol;

  /** Returns the current setting value for the provided data key. You shall
      only use validated keys otherwise you might fallback to default values. */
  loadValue(dataKey?: string) {
    return this.decoder(dataKey ? this.loadData(dataKey) : undefined)
  }

  /** Push the new setting value for the provided data key.
      You only use validated keys otherwise further loads
      might fail and fallback to defaults. */
  saveValue(dataKey: string, value: A) {
    this.saveData(dataKey, this.encoder(value));
  }

}

/**
   Generic React Hook to be used with any kind of [[Settings]].
   You may share `dataKey` between components, or change it dynamically.
   However, a given data key shall always be used for the same Setting instance.
   See [[Settings]] documentation for details.
   @param S - the instance settings to be used
   @param dataKey - identifies which value in the settings to be used
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
    You can use a [[JSON.Loose]] decoder for optional values. */
export class WindowSettingsData<A> extends Settings<A> {

  constructor(role: string, decoder: JSON.Safe<A>, encoder: JSON.Encoder<A>) {
    super(role, decoder, encoder);
  }

  event = Symbol('dome.settings');
  loadData(key: string) { return Dome.getWindowSetting(key) as JSON.json; }
  saveData(key: string, data: JSON.json) { Dome.setWindowSetting(key, data); }

}

/** Global Settings for non-JSON data.
    In most situations, you can use [[WindowSettings]] instead.
    You can use a [[JSON.Loose]] decoder for optional values. */
export class GlobalSettingsData<A> extends Settings<A> {

  constructor(role: string, decoder: JSON.Safe<A>, encoder: JSON.Encoder<A>) {
    super(role, decoder, encoder);
  }

  event = Symbol('dome.globals');
  loadData(key: string) { return Dome.getGlobalSetting(key) as JSON.json; }
  saveData(key: string, data: JSON.json) { Dome.setGlobalSetting(key, data); }

}

/** Window Settings.
    For non-JSON data, use [[WindowSettingsdata]] instead.
    You can use a [[JSON.Loose]] decoder for optional values. */
export class WindowSettings<A extends JSON.json> extends WindowSettingsData<A> {

  constructor(role: string, decoder: JSON.Safe<A>) {
    super(role, decoder, JSON.identity);
  }

}

/** Global Settings.
    For non-JSON data, use [[WindowSettingsdata]] instead.
    You can use a [[JSON.Loose]] decoder for optional values. */
export class GlobalSettings<A extends JSON.json> extends GlobalSettingsData<A> {

  constructor(role: string, decoder: JSON.Safe<A>) {
    super(role, decoder, JSON.identity);
  }

}

// --------------------------------------------------------------------------
