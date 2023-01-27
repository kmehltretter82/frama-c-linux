/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

/**
   Safe ARRAY utilities.
   @packageDocumentation
   @module dome/data/arrays
*/

/** Swaps items at index i and j if they are both in range. */
export function swap<A>(ls: A[], a: number, b: number): A[] {
  const n = ls.length;
  if (a === b || 0 > a || a >= n || 0 > b || b >= n) return ls;
  const [i, j] = a < b ? [a, b] : [b, a];
  return ls.slice(0, i).concat(ls.slice(i + 1, j + 1), ls[i], ls.slice(j + 1));
}

/** Remove item at index i when in range. */
export function removeAt<A>(ls: A[], k: number): A[] {
  return 0 <= k && k < ls.length ? ls.slice(0, k).concat(ls.slice(k + 1)) : ls;
}

/** Insert an item at index i when in range or off-by-one. */
export function insertAt<A>(ls: A[], id: A, k: number): A[] {
  return 0 <= k && k <= ls.length ? ls.slice(0, k).concat(id, ls.slice(k)) : ls;
}


export type Indexed = { key: unknown; }

/** Merges elements of the second array into matching elements of the first.
    The length and order of the first array is preserved. Elements of the second
    array matching no element of the first are ignored. */
export function mergeArrays<A, B>(
  a1: A[],
  a2: B[],
  match: (x1: A, x2: B) => boolean): (A | (A & B))[] {
  return a1.map(x1 => ({...x1, ...(a2.find(x2 => match(x1, x2)))}));
}

/** Same as mergeArrays, using the `key` field to match between array items. */
export function mergeArraysByKey<A, B>(
  a1: (A & Indexed)[],
  a2: (B & Indexed)[]
): (A | A & B)[] {
  return mergeArrays(a1, a2, (x1, x2) => x1.key === x2.key);
}
