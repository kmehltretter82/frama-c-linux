// --------------------------------------------------------------------------
// --- JSON Utilities
// --------------------------------------------------------------------------

import { DEVEL } from 'dome/system';

/**
   Safe JSON utilities.
   @package dome/data/json
*/

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
   Export JSON (or any data) as a string with indented content.
 */
export function pretty(js: any) {
  return JSON.stringify(js, undefined, 2);
}

// --------------------------------------------------------------------------
// --- SAFE Decoder
// --------------------------------------------------------------------------

/** Decoder for values of type `D`. */
export type Safe<D> = (js: json) => D;

/**
   Decode for values of type `D`, if any.
   Same as `Safe<D | undefined>`.
*/
export type Loose<D> = (js: json) => D | undefined;

// --------------------------------------------------------------------------
// --- Primitives
// --------------------------------------------------------------------------

/** Primitive JSON number or `undefined`. */
export const jNumber: Loose<number> = (js: json) => (
  typeof js === 'number' ? js : undefined
);

/** Primitive JSON number or `0`. */
export const jZero: Safe<number> = (js: json) => (
  typeof js === 'number' ? js : 0
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
    } catch (_err) {
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
        const fv = fn(js[k]);
        buffer[k as keyof A] = fv;
      }
      return buffer;
    }
    return undefined;
  };
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
        const fv = fn(js[k]);
        if (fv) buffer[k] = fv;
      }
    }
    return buffer;
  };
}

// --------------------------------------------------------------------------
