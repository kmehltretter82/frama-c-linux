// --------------------------------------------------------------------------
// --- JSON Utilities
// --------------------------------------------------------------------------

/**
   Safe JSON utilities.
   @packageDocumentation
   @package dome/data/json
*/

import { DEVEL } from 'dome/system';

export type json =
  undefined | null | number | string | json[] | { [key: string]: json }

/**
   Parse without _revivals_.
   Returned data is guaranteed to have only [[json]] type.
   If an error occurs and `noError` is set to `true`,
   the function returns `undefined` and logs the error in console
   (DEVEL mode only).
 */
export function parse(text: string, noError = false): json {
  if (noError) {
    try {
      return JSON.parse(text);
    } catch (err) {
      if (DEVEL) console.error('[Dome.json] invalid format:', err);
      return undefined;
    }
  } else
    return JSON.parse(text);
}

/**
   Export JSON (or any data) as a compact string.
*/
export function stringify(js: any) {
  return JSON.stringify(js, undefined, 0);
}

/**
   Export JSON (or any data) as a string with indentation.
 */
export function pretty(js: any) {
  return JSON.stringify(js, undefined, 2);
}

// --------------------------------------------------------------------------
// --- SAFE Decoder
// --------------------------------------------------------------------------

/** Decoder for values of type `D`.
    You can abbreviate `Safe<D | undefined>` with `Loose<D>`. */
export type Safe<D> = (js?: json) => D;

/** Decoder for values of type `D`, if any.
    Same as `Safe<D | undefined>`. */
export type Loose<D> = (js?: json) => D | undefined;

/**
   Encoder for value of type `D`.
   In most cases, you only need [[identity]].
 */
export type Encoder<D> = (v: D) => json;

/** Can be used for most encoders. */
export function identity<A>(v: A): A { return v; };

// --------------------------------------------------------------------------
// --- Primitives
// --------------------------------------------------------------------------

/** Primitive JSON number or `undefined`. */
export const jNumber: Loose<number> = (js: json) => (
  typeof js === 'number' && !Number.isNaN(js) ? js : undefined
);

/** Primitive JSON number, rounded to integer, or `undefined`. */
export const jInt: Loose<number> = (js: json) => (
  typeof js === 'number' && !Number.isNaN(js) ? Math.round(js) : undefined
);

/** Primitive JSON number or `0`. */
export const jZero: Safe<number> = (js: json) => (
  typeof js === 'number' && !Number.isNaN(js) ? js : 0
);

/** Primitive JSON boolean or `undefined`. */
export const jBoolean: Loose<boolean> = (js: json) => (
  typeof js === 'boolean' ? js : undefined
);

/** Primitive JSON boolean or `true`. */
export const jTrue: Safe<boolean> = (js: json) => (
  typeof js === 'boolean' ? js : true
);

/** Primitive JSON boolean or `false`. */
export const jFalse: Safe<boolean> = (js: json) => (
  typeof js === 'boolean' ? js : false
);

/** Primitive JSON string or `undefined`. */
export const jString: Loose<string> = (js: json) => (
  typeof js === 'string' ? js : undefined
);

/**
   One of the enumerated _constants_ or `undefined`.
   The typechecker will prevent you from listing values that are not in
   type `A`. However, it will not protected you
   from missings constants in `A`.
*/
export function jEnum<A>(...values: ((string | number) & A)[]): Loose<A> {
  var m = new Map<string | number, A>();
  values.forEach(v => m.set(v, v));
  return (v: json) => (typeof v === 'string' ? m.get(v) : undefined);
}

/**
   Refine a loose decoder with some default value.
   The default value is returned when the provided JSON is `undefined` or
   when the loose decoder returns `undefined`.
 */
export function jDefault<A>(
  fn: Loose<A>,
  defaultValue: A,
): Safe<A> {
  return (js: json) => js === undefined ? defaultValue : (fn(js) ?? defaultValue);
}

/**
   Force returning `undefined` or a default value for `undefined` JSON input.
   Typically usefull to leverage an existing `Safe<A>` decoder.
 */
export function jOption<A>(fn: Safe<A>, defaultValue?: A): Loose<A> {
  return (js: json) => (js === undefined ? defaultValue : fn(js));
}

/**
   Force returning `undefined` or a default value for `undefined` _or_ `null`
   JSON input. Typically usefull to leverage an existing `Safe<A>` decoder.
 */
export function jNull<A>(fn: Safe<A>, defaultValue?: A): Loose<A> {
  return (js: json) => (js === undefined || js === null ? defaultValue : fn(js));
}

/**
   Fail when the loose decoder returns `undefined`.
   See also [[jCatch]] and [[jTry]].
 */
export function jFail<A>(fn: Loose<A>, error: Error): Safe<A> {
  return (js: json) => {
    const d = fn(js);
    if (d !== undefined) return d;
    throw error;
  };
}

/**
   Provide a fallback value in case of undefined value or error.
   See also [[jFail]] and [[jTry]].
 */
export function jCatch<A>(fn: Loose<A>, fallBack: A): Safe<A> {
  return (js: json) => {
    try {
      return fn(js) ?? fallBack;
    } catch (err) {
      if (DEVEL) console.error('[Dome.json]', err);
      return fallBack;
    }
  };
}

/**
   Provides an (optional) default value in case of error or undefined value.
   See also [[jFail]] and [[jCatch]].
 */
export function jTry<A>(fn: Loose<A>, defaultValue?: A): Loose<A> {
  return (js: json) => {
    try {
      return fn(js) ?? defaultValue;
    } catch (_err) {
      return defaultValue;
    }
  };
}

/**
   Converts maps to dictionnaries.
 */
export function jMap<A>(fn: Loose<A>): Safe<Map<string, A>> {
  return (js: json) => {
    const m = new Map<string, A>();
    if (js !== null && typeof js === 'object' && !Array.isArray(js)) {
      for (let k of Object.keys(js)) {
        const v = fn(js[k]);
        if (v !== undefined) m.set(k, v);
      }
    }
    return m;
  };
}

/**
   Converts dictionnaries to maps.
 */
export function eMap<A>(fn: Encoder<A>): Encoder<Map<string, undefined | A>> {
  return m => {
    const js: json = {};
    m.forEach((v, k) => {
      if (v !== undefined) {
        const u = fn(v);
        if (u !== undefined) js[k] = u;
      }
    });
    return js;
  };
}

/**
   Apply the decoder on each item of a JSON array, or return `[]` otherwize.
   Can be also applied on a _loose_ decoder, but you will get
   an array with possibly `undefined` elements. Use [[jList]]
   to discard undefined elements, or use a true « safe » decoder.
 */
export function jArray<A>(fn: Safe<A>): Safe<A[]> {
  return (js: json) => Array.isArray(js) ? js.map(fn) : [];
}

/**
   Apply the loose decoder on each item of a JSON array, discarding
   all `undefined` elements. To keep all, possibly undefined array entries,
   use [[jArray]] instead.
 */
export function jList<A>(fn: Loose<A>): Safe<A[]> {
  return (js: json) => {
    const buffer: A[] = [];
    if (Array.isArray(js)) js.forEach(vj => {
      const d = fn(vj);
      if (d !== undefined) buffer.push(d);
    });
    return buffer;
  };
}

/**
   Exports all non-undefined elements.
 */
export function eList<A>(fn: Encoder<A>): Encoder<(A | undefined)[]> {
  return m => {
    const js: json[] = [];
    m.forEach(v => {
      if (v !== undefined) {
        const u = fn(v);
        if (u !== undefined) js.push(u);
      }
    });
    return js;
  };
}

/** Apply a pair of decoders to JSON pairs, or return `undefined`. */
export function jPair<A, B>(
  fa: Safe<A>,
  fb: Safe<B>,
): Loose<[A, B]> {
  return (js: json) => Array.isArray(js) ? [
    fa(js[0]),
    fb(js[1]),
  ] : undefined;
}

/** Similar to [[jPair]]. */
export function jTriple<A, B, C>(
  fa: Safe<A>,
  fb: Safe<B>,
  fc: Safe<C>,
): Loose<[A, B, C]> {
  return (js: json) => Array.isArray(js) ? [
    fa(js[0]),
    fb(js[1]),
    fc(js[2]),
  ] : undefined;
}

/** Similar to [[jPair]]. */
export function jTuple4<A, B, C, D>(
  fa: Safe<A>,
  fb: Safe<B>,
  fc: Safe<C>,
  fd: Safe<D>,
): Loose<[A, B, C, D]> {
  return (js: json) => Array.isArray(js) ? [
    fa(js[0]),
    fb(js[1]),
    fc(js[2]),
    fd(js[3]),
  ] : undefined;
}

/** Similar to [[jPair]]. */
export function jTuple5<A, B, C, D, E>(
  fa: Safe<A>,
  fb: Safe<B>,
  fc: Safe<C>,
  fd: Safe<D>,
  fe: Safe<E>,
): Loose<[A, B, C, D, E]> {
  return (js: json) => Array.isArray(js) ? [
    fa(js[0]),
    fb(js[1]),
    fc(js[2]),
    fd(js[3]),
    fe(js[4]),
  ] : undefined;
}

/**
   Decoders for each property of object type `A`.
   Optional fields in `A` can be assigned a loose decoder.
*/
export type Props<A> = {
  [P in keyof A]: Safe<A[P]>;
}

/**
   Decode an object given the decoders of its fields.
   Returns `undefined` for non-object JSON.
 */
export function jObject<A>(fp: Props<A>): Loose<A> {
  return (js: json) => {
    if (js !== null && typeof js === 'object' && !Array.isArray(js)) {
      const buffer = {} as A;
      for (var k of Object.keys(fp)) {
        const fn = fp[k as keyof A];
        if (fn !== undefined) {
          const fj = js[k];
          if (fj !== undefined) {
            const fv = fn(fj);
            if (fv !== undefined) buffer[k as keyof A] = fv;
          }
        }
      }
      return buffer;
    }
    return undefined;
  };
}

/**
   Encoders for each property of object type `A`.
*/
export type EProps<A> = {
  [P in keyof A]?: Encoder<A[P]>;
}

/**
   Encode an object given the provided encoders by fields.
   The exported JSON object has only original
   fields with some specified encoder.
 */
export function eObject<A>(fp: EProps<A>): Encoder<A> {
  return (m: A) => {
    const js: json = {};
    for (var k of Object.keys(fp)) {
      const fn = fp[k as keyof A];
      if (fn !== undefined) {
        const fv = m[k as keyof A];
        if (fv !== undefined) {
          const r = fn(fv);
          if (r !== undefined) js[k] = r;
        }
      }
    }
    return js;
  }
}

/** Type of dictionaries. */
export type dict<A> = { [key: string]: A };

/**
   Decode a JSON dictionary, dicarding all inconsistent entries.
   If the JSON contains no valid entry, still returns `{}`.
*/
export function jDictionary<A>(fn: Loose<A>): Safe<dict<A>> {
  return (js: json) => {
    const buffer: dict<A> = {};
    if (js !== null && typeof js === 'object' && !Array.isArray(js)) {
      for (var k of Object.keys(js)) {
        const fd = js[k];
        if (fd !== undefined) {
          const fv = fn(fd);
          if (fv !== undefined) buffer[k] = fv;
        }
      }
    }
    return buffer;
  };
}

/**
   Encode a dictionary into JSON, dicarding all inconsistent entries.
   If the dictionary contains no valid entry, still returns `{}`.
*/
export function eDictionary<A>(fn: Encoder<A>): Encoder<dict<A>> {
  return (d: dict<A>) => {
    const js: json = {};
    for (var k of Object.keys(d)) {
      const fv = d[k];
      if (fv !== undefined) {
        const fv = fn(d[k]);
        if (fv !== undefined) js[k] = fv;
      }
    }
    return js;
  };
}

// --------------------------------------------------------------------------
