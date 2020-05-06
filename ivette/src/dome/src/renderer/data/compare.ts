// --------------------------------------------------------------------------
// --- Comparison Utilities
// --------------------------------------------------------------------------

/**
   Data comparisons.
   @packageDocumentation
   @module dome/data/compare
*/

/**
   Interface for comparison functions.
   These function shall fullfill the following contract:
   - `compare(x,y) == 0` shall be an equivalence relation (reflexive, symmetric, transitive)
   - `compare(x,y) <= 0` shall be a complete order (reflexive, antisymetric, transitive)
   - `compare(x,y) < 0` shall be a complete strict order (anti-reflexive, asymetric, transitive)
*/
export interface Compare<A> {
  (x: A, y: A): number;
}

type bignumber = number | bigint

/** Type guard for number or bigint. */
export function isNumber(x: any): x is bignumber {
  if (typeof x === 'number') return true;
  if (typeof x === 'bigint') return true;
  return false;
}

/**
   Primitive comparison.
   Can only compare arguments that have
   exactly the same primitive type.
*/
export function primitive(x: symbol, y: symbol): number;
export function primitive(x: boolean, y: boolean): number;
export function primitive(x: bignumber, y: bignumber): number;
export function primitive(x: string, y: string): number;
export function primitive(x: any, y: any) {
  if (x < y) return -1;
  if (x > y) return 1;
  return 0;
}

/**
   Alphabetic comparison for strings.
   Handles case differently than `byString` comparison.
*/
export function alpha(x: string, y: string) {
  const cmp = primitive(x.toLowerCase(), y.toLowerCase());
  return cmp != 0 ? cmp : primitive(x, y);
}

/** Combine comparison orders in sequence. */
export function sequence<A>(...orders: Compare<A>[]): Compare<A> {
  return (x: A, y: A) => {
    for (const order of orders) {
      const cmp = order(x, y);
      if (cmp != 0) return cmp;
    }
    return 0;
  };
}

/** Compare optional values. */
export function option<A>(order: Compare<A>): Compare<undefined | A> {
  return (x?: A, y?: A) => {
    if (x == undefined && y == undefined) return 0;
    if (x == undefined) return -1;
    if (y == undefined) return 1;
    return order(x, y);
  };
}

/** Lexicographic comparison of array elements. */
export function array<A>(order: Compare<A>): Compare<A[]> {
  return (x: A[], y: A[]) => {
    const p = x.length;
    const q = y.length;
    const m = p < q ? p : q;
    for (let k = 0; k < m; k++) {
      const cmp = order(x[k], y[k]);
      if (cmp != 0) return cmp;
    }
    return p - q;
  };
}

/** Direct or reverse direction. */
export function direction<A>(order: Compare<A>, reverse = false): Compare<A> {
  return (x, y) => reverse ? order(y, x) : order(x, y);
}

/** By projection. */
export function lift<A, B>(fn: (x: A) => B, order: Compare<B>): Compare<A> {
  return (x: A, y: A) => order(fn(x), fn(y));
}

/** Return own property names of its object argument. */
export function getKeys<T>(a: T): (keyof T)[] {
  return Object.getOwnPropertyNames(a) as (keyof T)[];
}

/**
   Maps each field to some _optional_ comparison of the associated type.
   Hence, `ByFields<{…, f: T, …}>` is `{…, f?: Compare<T>, …}`.
   See [[fields]] comparison function.
 */
type ByFields<A> = {
  [P in keyof A]?: Compare<A[P]>;
}

/**
   Maps _all_ fields to a comparison of the associated type.
   Hence, `ByAllFields<{…, f: T, …}>` is `{…, f: Compare<T>, …}`.
   See [[fieldsComplete]] comparison function.
*/
type ByAllFields<A> = {
  [P in keyof A]: Compare<A[P]>;
}

/** Object comparison by (some) fields.

    Compare objects field by field, using the comparison orders provided by the
    `order` argument. Order of field comparison is taken from the `order`
    argument, not from the compared values.

    You may not compare _all_ fields of the compared values.  For optional
    fields, you shall provide a comparison function compatible with type
    `undefined`.

    It might be difficult for Typescript to typecheck `fields(…)` expressions
    when dealing with optional types. In such cases, you shall use `fields<A>(…)`
    and explicitly mention the type of compared values.

    Example:

        type foo = { id: number, name?: string, descr?: string }
        const compare = fields<foo>({ id: byNumber, name: option(byAlpha) });

*/
export function fields<A>(order: ByFields<A>): Compare<A> {
  return (x: A, y: A) => {
    for (const fd of getKeys(order)) {
      const byFd = order[fd];
      if (byFd !== undefined) {
        const cmp = byFd(x[fd], y[fd]);
        if (cmp != 0) return cmp;
      }
    }
    return 0;
  };
}

/** Complete object comparison.
    This is similar to `fields()` comparison, but an ordering function must be
    provided for _any_ field (optional or not) of the compared values.
*/
export function fieldsComplete<A>(order: ByAllFields<A>): Compare<A> {
  return (x: A, y: A) => {
    for (const fd of getKeys<ByFields<A>>(order)) {
      const byFd = order[fd];
      const cmp = byFd(x[fd], y[fd]);
      if (cmp != 0) return cmp;
    }
    return 0;
  };
}

/** Pair comparison. */
export function pair<A, B>(ordA: Compare<A>, ordB: Compare<B>): Compare<[A, B]> {
  return ([x1, y1], [x2, y2]) => {
    const cmp = ordA(x1, x2);
    return cmp != 0 ? cmp : ordB(y1, y2);
  };
}

/** Triple comparison. */
export function triple<A, B, C>(
  ordA: Compare<A>,
  ordB: Compare<B>,
  ordC: Compare<C>,
): Compare<[A, B, C]> {
  return ([x1, y1, z1], [x2, y2, z2]) => {
    const cmp1 = ordA(x1, x2);
    if (cmp1 != 0) return cmp1;
    const cmp2 = ordB(y1, y2);
    if (cmp2 != 0) return cmp2;
    return ordC(z1, z2);
  };
}

/** 4-Tuple comparison. */
export function tuple4<A, B, C, D>(
  ordA: Compare<A>,
  ordB: Compare<B>,
  ordC: Compare<C>,
  ordD: Compare<D>,
): Compare<[A, B, C, D]> {
  return ([x1, y1, z1, t1], [x2, y2, z2, t2]) => {
    const cmp1 = ordA(x1, x2);
    if (cmp1 != 0) return cmp1;
    const cmp2 = ordB(y1, y2);
    if (cmp2 != 0) return cmp2;
    const cmp3 = ordC(z1, z2);
    if (cmp3 != 0) return cmp3;
    return ordD(t1, t2);
  };
}

/** 5-Tuple comparison. */
export function tuple5<A, B, C, D, E>(
  ordA: Compare<A>,
  ordB: Compare<B>,
  ordC: Compare<C>,
  ordD: Compare<D>,
  ordE: Compare<E>,
): Compare<[A, B, C, D, E]> {
  return ([x1, y1, z1, t1, u1], [x2, y2, z2, t2, u2]) => {
    const cmp1 = ordA(x1, x2);
    if (cmp1 != 0) return cmp1;
    const cmp2 = ordB(y1, y2);
    if (cmp2 != 0) return cmp2;
    const cmp3 = ordC(z1, z2);
    if (cmp3 != 0) return cmp3;
    const cmp4 = ordD(t1, t2);
    if (cmp4 != 0) return cmp4;
    return ordE(u1, u2);
  };
}

// --------------------------------------------------------------------------
// --- Structural Comparison
// --------------------------------------------------------------------------

/** @internal */
function rank(x: any): number {
  let t = typeof x;
  switch (t) {
    case 'undefined': return 0;
    case 'boolean': return 1;
    case 'symbol': return 2;
    case 'number': case 'bigint': return 3;
    case 'string': return 4;
    case 'object': return Array.isArray(x) ? 5 : 6;
    case 'function': return 7;
  }
}

/**
   Universal structural comparison.
   Values are ordered by _rank_, each being associated with some type of values:
    - rank 0: undefined values;
    - rank 1: booleans;
    - rank 2: symbols;
    - rank 3: numbers and bigint (See `isNumber()`);
    - rank 4: arrays (See `Array.isArray()`);
    - rank 5: objects;
    - rank 6: functions.

   For values of same primitive type, primitive ordering is performed.

   For array values, lexicographic ordering is performed.

   For object values, lexicographic ordering is performed over their properties:
   properties are ordered by name, and recursive structural ordering is performed
   on property values.

   All functions are compared equal.
 */
export function structural(x: any, y: any): number {
  if (isNumber(x) && isNumber(y)) return primitive(x, y);
  if (typeof x === 'symbol' && typeof y === 'symbol') return primitive(x, y);
  if (typeof x === 'boolean' && typeof y === 'boolean') return primitive(x, y);
  if (typeof x === 'string' && typeof y === 'string') return primitive(x, y);
  if (Array.isArray(x) && Array.isArray(y)) return array(structural)(x, y);
  if (typeof x === 'object' && typeof y === 'object') {
    const fs = Object.getOwnPropertyNames(x).sort();
    const gs = Object.getOwnPropertyNames(y).sort();
    const p = fs.length;
    const q = gs.length;
    for (let i = 0, j = 0; i < p && j < q;) {
      let a = undefined, b = undefined;
      const f = fs[i];
      const g = gs[j];
      if (f <= g) { a = x[f]; i++; }
      if (g <= f) { b = y[g]; j++; }
      const cmp = structural(a, b);
      if (cmp != 0) return cmp;
    }
    return p - q;
  }
  return rank(x) - rank(y);
};

// --------------------------------------------------------------------------
