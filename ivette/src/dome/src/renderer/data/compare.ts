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
   - `compare(x,y) == 0` shall be an equivalence relation
     (reflexive, symmetric, transitive)
   - `compare(x,y) <= 0` shall be a complete order
     (reflexive, antisymetric, transitive)
   - `compare(x,y) < 0` shall be a complete strict order
     (anti-reflexive, asymetric, transitive)
*/
export interface Order<A> {
  (x: A, y: A): number;
}

export function equal(_x: any, _y: any): 0 { return 0; }

export type bignum = bigint | number;

/** Non-NaN numbers and big-ints */
export function isBigNum(x: any): x is bignum {
  return typeof (x) === 'bigint' || (typeof (x) === 'number' && !Number.isNaN(x));
}

/**
   Primitive comparison.
   Can only compare arguments that have
   comparable primitive type.

   This includes symbols, boolean, non-NaN numbers, bigints and strings.
   Numbers and big-ints can also be compared with each others.
*/
export function primitive(x: symbol, y: symbol): number;
export function primitive(x: boolean, y: boolean): number;
export function primitive(x: bignum, y: bignum): number;
export function primitive(x: string, y: string): number;
export function primitive(x: any, y: any) {
  if (x < y) return -1;
  if (x > y) return 1;
  return 0;
}

/**
   Primitive comparison for numbers (NaN included).
 */
export function float(x: number, y: number) {
  const nx = Number.isNaN(x);
  const ny = Number.isNaN(y);
  if (nx && ny) return 0;
  if (nx && !ny) return -1;
  if (!nx && ny) return 1;
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
export function sequence<A>(...orders: (Order<A> | undefined)[]): Order<A> {
  return (x: A, y: A) => {
    if (x === y) return 0;
    for (const order of orders) {
      if (order) {
        const cmp = order(x, y);
        if (cmp != 0) return cmp;
      }
    }
    return 0;
  };
}

/** Compare optional values. Undefined values come first. */
export function option<A>(order: Order<A>): Order<undefined | A> {
  return (x?: A, y?: A) => {
    if (x == undefined && y == undefined) return 0;
    if (x == undefined) return -1;
    if (y == undefined) return 1;
    return order(x, y);
  };
}

/** Compare optional values. Undefined values come last. */
export function defined<A>(order: Order<A>): Order<undefined | A> {
  return (x?: A, y?: A) => {
    if (x == undefined && y == undefined) return 0;
    if (x == undefined) return 1;
    if (y == undefined) return -1;
    return order(x, y);
  };
}

/** Lexicographic comparison of array elements. */
export function array<A>(order: Order<A>): Order<A[]> {
  return (x: A[], y: A[]) => {
    if (x === y) return 0;
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

/** Order string enumeration constants.
    `enums(v1,...,vN)` will order constant following the order of arguments.
    Non-listed constants appear at the end, or at the rank specified by `'*'`. */
export function byRank(...args: string[]): Order<string> {
  const ranks: { [index: string]: number } = {};
  args.forEach((C, k) => ranks[C] = k);
  const wildcard = ranks['*'] ?? ranks.length;
  return (x: string, y: string) => {
    if (x === y) return 0;
    const rx = ranks[x] ?? wildcard;
    const ry = ranks[y] ?? wildcard;
    if (rx == wildcard && ry == wildcard)
      return primitive(x, y);
    else
      return rx - ry;
  };
}

/** Direct or reverse direction. */
export function direction<A>(order: Order<A>, reverse = false): Order<A> {
  return (x, y) => (x === y ? 0 : reverse ? order(y, x) : order(x, y));
}

/** By projection. */
export function lift<A, B>(fn: (x: A) => B, order: Order<B>): Order<A> {
  return (x: A, y: A) => (x === y ? 0 : order(fn(x), fn(y)));
}

/** Return own property names of its object argument. */
export function getKeys<T>(a: T): (keyof T)[] {
  return Object.getOwnPropertyNames(a) as (keyof T)[];
}

/**
   Maps each field of `A` to some _optional_ comparison of the associated type.
   Hence, `ByFields<{…, f: T, …}>` is `{…, f?: Order<T>, …}`.
   See [[fields]] comparison function.
 */
export type ByFields<A> = {
  [P in keyof A]?: Order<A[P]>;
}

/**
   Maps each field of `A` to some comparison of the associated type.
   Hence, `ByAllFields<{…, f: T, …}>` is `{…, f: Order<T>, …}`.
   See [[fieldsComplete]] comparison function.
*/
export type ByAllFields<A> = {
  [P in keyof A]: Order<A[P]>;
}

/** Object comparison by (some) fields.

    Compare objects field by field, using the comparison orders provided by the
    `order` argument. Order of field comparison is taken from the `order`
    argument, not from the compared values.

    You may not compare _all_ fields of the compared values.  For optional
    fields, you shall provide a comparison function compatible with type
    `undefined`.

    It might be difficult for Typescript to typecheck `byFields(…)` expressions
    when dealing with optional types. In such cases, you shall use `byFields<A>(…)`
    and explicitly mention the type of compared values.

    Example:

        type foo = { id: number, name?: string, descr?: string }
        const compare = fields<foo>({ id: number, name: option(alpha) });

*/
export function byFields<A>(order: ByFields<A>): Order<A> {
  return (x: A, y: A) => {
    if (x === y) return 0;
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
    This is similar to `byFields()` comparison, but an ordering function must be
    provided for _any_ field (optional or not) of the compared values.
*/
export function byAllFields<A>(order: ByAllFields<A>): Order<A> {
  return (x: A, y: A) => {
    if (x === y) return 0;
    for (const fd of getKeys<ByFields<A>>(order)) {
      const byFd = order[fd];
      const cmp = byFd(x[fd], y[fd]);
      if (cmp != 0) return cmp;
    }
    return 0;
  };
}

export type dict<A> = undefined | null | { [key: string]: A };

/**
   Compare dictionaries _wrt_ lexicographic order of entries.
*/
export function dictionary<A>(order: Order<A>): Order<dict<A>> {
  return (x: dict<A>, y: dict<A>) => {
    if (x === y) return 0;
    const dx = x ?? {};
    const dy = y ?? {};
    const phi = option(order);
    const fs = Object.getOwnPropertyNames(dx).sort();
    const gs = Object.getOwnPropertyNames(dy).sort();
    const p = fs.length;
    const q = gs.length;
    for (let i = 0, j = 0; i < p && j < q;) {
      let a = undefined, b = undefined;
      const f = fs[i];
      const g = gs[j];
      if (f <= g) { a = dx[f]; i++; }
      if (g <= f) { b = dy[g]; j++; }
      const cmp = phi(a, b);
      if (cmp != 0) return cmp;
    }
    return p - q;
  };
}

/** Pair comparison. */
export function pair<A, B>(ordA: Order<A>, ordB: Order<B>): Order<[A, B]> {
  return (u, v) => {
    if (u === v) return 0;
    const [x1, y1] = u;
    const [x2, y2] = v;
    const cmp = ordA(x1, x2);
    return cmp != 0 ? cmp : ordB(y1, y2);
  };
}

/** Triple comparison. */
export function triple<A, B, C>(
  ordA: Order<A>,
  ordB: Order<B>,
  ordC: Order<C>,
): Order<[A, B, C]> {
  return (u, v) => {
    if (u === v) return 0;
    const [x1, y1, z1] = u;
    const [x2, y2, z2] = v;
    const cmp1 = ordA(x1, x2);
    if (cmp1 != 0) return cmp1;
    const cmp2 = ordB(y1, y2);
    if (cmp2 != 0) return cmp2;
    return ordC(z1, z2);
  };
}

/** 4-Tuple comparison. */
export function tuple4<A, B, C, D>(
  ordA: Order<A>,
  ordB: Order<B>,
  ordC: Order<C>,
  ordD: Order<D>,
): Order<[A, B, C, D]> {
  return (u, v) => {
    if (u === v) return 0;
    const [x1, y1, z1, t1] = u;
    const [x2, y2, z2, t2] = v;
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
  ordA: Order<A>,
  ordB: Order<B>,
  ordC: Order<C>,
  ordD: Order<D>,
  ordE: Order<E>,
): Order<[A, B, C, D, E]> {
  return (u, v) => {
    if (u === v) return 0;
    const [x1, y1, z1, t1, w1] = u;
    const [x2, y2, z2, t2, w2] = v;
    const cmp1 = ordA(x1, x2);
    if (cmp1 != 0) return cmp1;
    const cmp2 = ordB(y1, y2);
    if (cmp2 != 0) return cmp2;
    const cmp3 = ordC(z1, z2);
    if (cmp3 != 0) return cmp3;
    const cmp4 = ordD(t1, t2);
    if (cmp4 != 0) return cmp4;
    return ordE(w1, w2);
  };
}

// --------------------------------------------------------------------------
// --- Structural Comparison
// --------------------------------------------------------------------------

/** @internal */
enum RANK { UNDEFINED, BOOLEAN, SYMBOL, NAN, BIGNUM, STRING, ARRAY, OBJECT, FUNCTION };

/** @internal */
function rank(x: any): RANK {
  let t = typeof x;
  switch (t) {
    case 'undefined': return RANK.UNDEFINED;
    case 'boolean': return RANK.BOOLEAN;
    case 'symbol': return RANK.SYMBOL;
    case 'number':
      return Number.isNaN(x) ? RANK.NAN : RANK.BIGNUM;
    case 'bigint':
      return RANK.BIGNUM;
    case 'string': return RANK.STRING;
    case 'object': return Array.isArray(x) ? RANK.ARRAY : RANK.OBJECT;
    case 'function': return RANK.FUNCTION;
  }
}

/**
   Universal structural comparison.
   Values are ordered by _rank_, each being associated with some type of values:
   1. undefined values;
   2. booleans;
   3. symbols;
   4. NaN numbers;
   5. non-NaN numbers and bigints;
   6. arrays;
   7. objects;
   8. functions;

   For values of same primitive type, primitive ordering is performed.

   For array values, lexicographic ordering is performed.

   For object values, lexicographic ordering is performed over their properties:
   properties are ordered by name, and recursive structural ordering is performed
   on property values.

   All functions are compared equal.
 */
export function structural(x: any, y: any): number {
  if (x === y) return 0;
  if (typeof x === 'symbol' && typeof y === 'symbol') return primitive(x, y);
  if (typeof x === 'boolean' && typeof y === 'boolean') return primitive(x, y);
  if (typeof x === 'string' && typeof y === 'string') return primitive(x, y);
  if (isBigNum(x) && isBigNum(y)) return primitive(x, y);
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
