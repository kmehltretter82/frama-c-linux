// --------------------------------------------------------------------------
// --- States
// --------------------------------------------------------------------------

/**
   Typed States & Settings
   @packageDocumentation
   @module dome/data/settings
*/

import React from 'react';
import { ipcRenderer } from 'electron';
import { debounce } from 'lodash';
import isEqual from 'react-fast-compare';
import { DEVEL, emitter as SysEmitter } from 'dome/misc/system';
import * as JSON from './json';
import type { State } from './states';

// --------------------------------------------------------------------------
// --- Settings
// --------------------------------------------------------------------------

/** @internal */
interface Settings<A> {
  decoder: JSON.Loose<A>;
  encoder: JSON.Encoder<A>;
  defaultValue: A;
}

/**
   Global settings.
   This utility class allows you to share accross several
   components and windows the parameters associated to global settings.

   However, it is important to note that global settings are uniquely identified
   by their `name`. If you have multiple definitions of global settings class
   with the same name, they will actually share the same value. Hence, if they
   have different default values or decoders, this might leads to strange
   results.
 */
export class GlobalSettings<A> {
  name: string;
  decoder: JSON.Loose<A>;
  encoder: JSON.Encoder<A>;
  defaultValue: A;
  constructor(
    name: string,
    decoder: JSON.Loose<A>,
    encoder: JSON.Encoder<A>,
    defaultValue: A,
  ) {
    this.name = name;
    this.decoder = decoder;
    this.encoder = encoder;
    this.defaultValue = defaultValue;
  }
}

// --------------------------------------------------------------------------
// --- Smart Constructors
// --------------------------------------------------------------------------

/** Boolean settings with `true` default. */
export class GTrue extends GlobalSettings<boolean> {
  constructor(name: string) {
    super(name, JSON.jBoolean, JSON.identity, true);
  }
}

/** Boolean settings with `false` default. */
export class GFalse extends GlobalSettings<boolean> {
  constructor(name: string) {
    super(name, JSON.jBoolean, JSON.identity, false);
  }
}

/** Numeric settings (default is zero unless specified). */
export class GNumber extends GlobalSettings<number> {
  constructor(name: string, defaultValue = 0) {
    super(name, JSON.jNumber, JSON.identity, defaultValue);
  }
}

/** String settings (default is `""` unless specified). */
export class GString extends GlobalSettings<string> {
  constructor(name: string, defaultValue = '') {
    super(name, JSON.jString, JSON.identity, defaultValue);
  }
}

/** Smart constructor for optional (JSON serializable) data. */
export class GOption<A extends JSON.json>
  extends GlobalSettings<A | undefined>
{
  constructor(name: string, encoder: JSON.Loose<A>, defaultValue?: A) {
    super(name, encoder, JSON.identity, defaultValue);
  }
}

/** Smart constructor for (JSON serializable) data with default. */
export class GDefault<A extends JSON.json> extends GlobalSettings<A> {
  constructor(name: string, encoder: JSON.Loose<A>, defaultValue: A) {
    super(name, encoder, JSON.identity, defaultValue);
  }
}

/** Smart constructor for object (JSON serializable) data. */
export class GObject<A extends JSON.json> extends GlobalSettings<A> {
  constructor(name: string, fields: JSON.Props<A>, defaultValue: A) {
    super(name, JSON.jObject(fields), JSON.identity, defaultValue);
  }
}

// --------------------------------------------------------------------------
// --- Generic Settings (private)
// --------------------------------------------------------------------------

type patch = { key: string; value: JSON.json };
type driver = { evt: string; ipc: string; broadcast: boolean };

class Driver {

  readonly evt: string; // broadcast event
  readonly broadcast: boolean; // settings broadcast
  readonly store: Map<string, JSON.json> = new Map();
  readonly diffs: Map<string, JSON.json> = new Map();
  readonly fire: (() => void) & { flush: () => void; cancel: () => void };

  constructor({ evt, ipc, broadcast }: driver) {
    this.evt = evt;
    this.broadcast = broadcast;
    // --- Update Events
    this.fire = debounce(() => {
      const m = this.diffs;
      if (m.size > 0) {
        const patches: patch[] = [];
        m.forEach((value, key) => {
          patches.push({ key, value });
        });
        m.clear();
        ipcRenderer.send(ipc, patches);
      }
    }, 100);
    // --- Restore Defaults Events
    ipcRenderer.on('dome.ipc.settings.defaults', () => {
      this.fire.cancel();
      this.store.clear();
      this.diffs.clear();
      SysEmitter.emit(this.evt);
    });
    // --- Broadcast Events
    if (this.broadcast) {
      ipcRenderer.on(
        'dome.ipc.settings.broadcast',
        (_sender, updates: patch[]) => {
          const m = this.store;
          const d = this.diffs;
          updates.forEach(({ key, value }) => {
            // Don't cancel local updates
            if (!d.has(key)) {
              if (value === null)
                m.delete(key);
              else
                m.set(key, value);
            }
          });
          SysEmitter.emit(this.evt);
        },
      );
    }
    // --- Closing Events
    ipcRenderer.on('dome.ipc.closing', () => {
      this.fire();
      this.fire.flush();
    });
  }

  // --- Initial Data

  sync(data: patch[]) {
    this.fire.cancel();
    this.store.clear();
    this.diffs.clear();
    const m = this.store;
    data.forEach(({ key, value }) => {
      m.set(key, value);
    });
    SysEmitter.emit(this.evt);
  }

  // --- Load Data

  load(key: string | undefined): JSON.json {
    return key === undefined ? undefined : this.store.get(key);
  }

  // --- Save Data

  save(key: string | undefined, data: JSON.json) {
    if (key === undefined) return;
    if (data === undefined) {
      this.store.delete(key);
      this.diffs.set(key, null);
    } else {
      this.store.set(key, data);
      this.diffs.set(key, data);
    }
    if (this.broadcast) SysEmitter.emit(this.evt);
    this.fire();
  }

}

// --------------------------------------------------------------------------
// --- Generic Settings Hook
// --------------------------------------------------------------------------

const keys = new Set<string>();

function useSettings<A>(
  S: Settings<A>,
  D: Driver,
  K?: string,
): State<A> {
  // Check for unique key
  React.useEffect(() => {
    if (K) {
      if (keys.has(K) && DEVEL)
        console.error('[Dome.settings] Duplicate key', K);
      else {
        keys.add(K);
        return () => { keys.delete(K); };
      }
    }
    return undefined;
  });
  // Load value
  const loader = () => (
    JSON.jCatch(S.decoder, S.defaultValue)(D.load(K))
  );
  // Local state
  const [value, setValue] = React.useState<A>(loader);
  // Broadcast
  React.useEffect(() => {
    if (K) {
      const event = D.evt;
      const callback = () => setValue(loader());
      SysEmitter.on(event, callback);
      return () => { SysEmitter.off(event, callback); };
    }
    return undefined;
  });
  // Updates
  const updateValue = React.useCallback((newValue: A) => {
    if (!isEqual(value, newValue)) {
      setValue(newValue);
      if (K) D.save(K, S.encoder(newValue));
    }
  }, [S, D, K, value]);
  return [value, updateValue];
}

// --------------------------------------------------------------------------
// --- Window Settings
// --------------------------------------------------------------------------

const WindowSettingsDriver = new Driver({
  evt: 'dome.settings.window',
  ipc: 'dome.ipc.settings.window',
  broadcast: false,
});

/**
   Returns the current value of the settings (default for undefined key).
 */
export function getWindowSettings<A>(
  key: string | undefined,
  decoder: JSON.Loose<A>,
  defaultValue: A,
): A {
  return key ?
    JSON.jCatch(decoder, defaultValue)(WindowSettingsDriver.load(key))
    : defaultValue;
}

/**
   Updates the current value of the settings (on defined key).
   Most settings are subtypes of `JSON` and do not require any specific
   encoder. If you have some, simply use it before updating the settings.
   See [[useWindowSettings]] and [[useWindowsettingsdata]].
 */
export function setWindowSettings(
  key: string | undefined,
  value: JSON.json,
) {
  if (key) WindowSettingsDriver.save(key, value);
}

/**
   Returns a local state that is saved back to the local window user settings.
   Local window settings are stored in the `.<appName>` file of the working
   directory, or in the closest one in parent directories, if any.
 */
export function useWindowSettings<A extends JSON.json>(
  key: string | undefined,
  decoder: JSON.Loose<A>,
  defaultValue: A,
) {
  return useSettings({
    decoder,
    encoder: JSON.identity,
    defaultValue,
  }, WindowSettingsDriver, key);
}

/** Same as [[useWindowSettings]] with a specific encoder. */
export function useWindowSettingsData<A>(
  key: string | undefined,
  decoder: JSON.Loose<A>,
  encoder: JSON.Encoder<A>,
  defaultValue: A,
) {
  return useSettings({
    decoder,
    encoder,
    defaultValue,
  }, WindowSettingsDriver, key);
}

/** Call the callback function on window settings events. */
export function useWindowSettingsEvent(callback: () => void) {
  React.useEffect(() => {
    const { evt } = WindowSettingsDriver;
    SysEmitter.on(evt, callback);
    return () => { SysEmitter.off(evt, callback); };
  });
}

/** @ignore DEPRECATED */
export function onWindowSettings(callback: () => void) {
  const { evt } = WindowSettingsDriver;
  SysEmitter.on(evt, callback);
}

/** @ignore DEPRECATED */
export function offWindowSettings(callback: () => void) {
  const { evt } = WindowSettingsDriver;
  SysEmitter.off(evt, callback);
}

// --------------------------------------------------------------------------
// --- Global Settings
// --------------------------------------------------------------------------

const GlobalSettingsDriver = new Driver({
  evt: 'dome.settings.global',
  ipc: 'dome.ipc.settings.window',
  broadcast: true,
});

/**
   Returns a global state, which is synchronized among all windows, and saved
   back in the global user settings. The global user settings file is located in
   the usual place for the application with respect to the underlying system.
 */
export function useGlobalSettings<A>(S: GlobalSettings<A>) {
  return useSettings(S, GlobalSettingsDriver, S.name);
}

/** Call the callback function on global settings events. */
export function useGlobalSettingsEvent(callback: () => void) {
  React.useEffect(() => {
    const { evt } = GlobalSettingsDriver;
    SysEmitter.on(evt, callback);
    return () => { SysEmitter.off(evt, callback); };
  });
}

// --------------------------------------------------------------------------
// --- Settings Synchronization
// --------------------------------------------------------------------------

/* @ internal */
export const window = WindowSettingsDriver.evt;

/* @ internal */
export const global = GlobalSettingsDriver.evt;

/* @ internal */
export function synchronize() {
  ipcRenderer.sendSync(
    'dome.ipc.settings.sync',
    (_event: string, data: any) => {
      const globals: patch[] = data.globals ?? [];
      GlobalSettingsDriver.sync(globals);
      const settings: patch[] = data.settings ?? [];
      WindowSettingsDriver.sync(settings);
    },
  );
}

// --------------------------------------------------------------------------
