// --------------------------------------------------------------------------
// --- Utilities
// --------------------------------------------------------------------------

import type { CSSProperties } from 'react';

export type ClassSpec =
  undefined | boolean | null | string |
  { [cname: string]: boolean | null | undefined };

export function classes(
  ...args: ClassSpec[]
): string {
  const buffer: string[] = [];
  args.forEach((cla) => {
    if (cla) {
      if (typeof (cla) === 'string' && cla !== '') buffer.push(cla);
      else if (typeof (cla) === 'object') {
        const cs = Object.keys(cla);
        cs.forEach((c) => { if (cla[c]) buffer.push(c); });
      }
    }
  });
  return buffer.join(' ');
}

export type StyleSpec =
  undefined | boolean | null | CSSProperties;

export function styles(
  ...args: StyleSpec[]
): CSSProperties | undefined {
  let empty = true;
  let buffer = {};
  args.forEach((sty) => {
    if (sty && typeof (sty) === 'object') {
      empty = false;
      buffer = { ...buffer, ...sty };
    }
  });
  return (empty ? undefined : buffer);
}

// --------------------------------------------------------------------------
