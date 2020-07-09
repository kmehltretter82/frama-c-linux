// --------------------------------------------------------------------------
// --- Utilities
// --------------------------------------------------------------------------

type specClass =
  undefined | boolean | null | string |
  { [cname: string]: boolean | null | undefined };

export function classes(
  ...args: specClass[]
): string {
  const buffer: string[] = [];
  args.forEach((spec) => {
    if (spec !== undefined && spec !== null) {
      if (typeof (spec) === 'string' && spec !== '') buffer.push(spec);
      else if (typeof (spec) === 'object') {
        const cs = Object.keys(spec);
        cs.forEach((c) => { if (spec[c]) buffer.push(c); });
      }
    }
  });
  return buffer.join(' ');
}

// --- please the linter

export default {};

// --------------------------------------------------------------------------
