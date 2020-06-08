// --------------------------------------------------------------------------
// --- JSON Utilities
// --------------------------------------------------------------------------

import { DEVEL } from 'dome/system';

/**
   Safe JSON utilities
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
   Export JSON as a compact string.
*/
export function stringify(js: json) {
  return JSON.stringify(js, undefined, 0);
}

/**
   Export JSON as a string with indented content.
 */
export function pretty(js: json) {
  return JSON.stringify(js, undefined, 2);
}

// --------------------------------------------------------------------------
// --- SAFE Decoder
// --------------------------------------------------------------------------

export type Loose<D> = (js: json) => D | undefined;
export type Strict<D> = (js: json) => D;

// --------------------------------------------------------------------------
// --- Primitives
// --------------------------------------------------------------------------

export const jNumber: Loose<number> = (js: json) => (
  typeof js === 'number' ? js : undefined
);

export const jZero: Strict<number> = (js: json) => (
  typeof js === 'number' ? js : 0
);

export const jBoolean: Loose<boolean> = (js: json) => (
  typeof js === 'boolean' ? js : undefined
);

export const jTrue: Strict<boolean> = (js: json) => (
  typeof js === 'boolean' ? js : true
);

export const jFalse: Strict<boolean> = (js: json) => (
  typeof js === 'boolean' ? js : false
);

export const jString: Loose<string> = (js: json) => (
  typeof js === 'string' ? js : undefined
);

export function jEnum(...values: string[]): Loose<string> {
  var m = new Map<string, string>();
  values.forEach(v => m.set(v, v));
  return (v: json) => (typeof v === 'string' ? m.get(v) : undefined);
}

export function jDefault<A>(
  fn: Loose<A>,
  defaultValue: A,
): Strict<A> {
  return (js: json) => js === undefined ? defaultValue : (fn(js) ?? defaultValue);
}

export function jArray<A>(fn: Strict<A>): Strict<A[]> {
  return (js: json) => Array.isArray(js) ? js.map(fn) : [];
}

export function jList<A>(fn: Loose<A>): Strict<A[]> {
  return (js: json) => {
    const buffer: A[] = [];
    if (Array.isArray(js)) js.forEach(vj => {
      const d = fn(vj);
      if (d !== undefined) buffer.push(d);
    });
    return buffer;
  };
}

export


// --------------------------------------------------------------------------
