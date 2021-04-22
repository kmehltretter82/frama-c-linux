/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

// --------------------------------------------------------------------------
// --- Sized Cell
// --------------------------------------------------------------------------

import React from 'react';

// --------------------------------------------------------------------------
// --- Measurer
// --------------------------------------------------------------------------

export class Streamer {
  private readonly v0: number;
  private readonly vs: number[] = [];
  private v?: number;
  constructor(v0: number) {
    this.v0 = v0;
  }

  push(v: number) {
    const { vs } = this;
    vs.push(Math.round(v));
    if (vs.length > 200) vs.shift();
  }

  mean(): number {
    if (this.v === undefined) {
      const { vs } = this;
      const n = vs.length;
      if (n > 0) {
        const m = vs.reduce((s, v) => s + v, 0) / n;
        this.v = Math.round(m + 0.5);
      } else {
        this.v = this.v0;
      }
    }
    return this.v;
  }

}

export class FontSizer {
  a = 0;
  b = 0;
  k: Streamer;
  p: Streamer;

  constructor(k: number, p: number) {
    this.k = new Streamer(k);
    this.p = new Streamer(p);
  }

  push(x: number, y: number) {
    const a0 = this.a;
    const b0 = this.b;
    if (x !== a0 && a0 !== 0) {
      const k = (y - b0) / (x - a0);
      const p = y - k * x;
      this.k.push(k);
      this.p.push(p);
    }
    this.a = x;
    this.b = y;
  }

  capacity(y: number) {
    const k = this.k.mean();
    const p = this.p.mean();
    return Math.round(0.5 + (y - p) / k);
  }

  dimension(n: number) {
    const k = this.k.mean();
    const p = this.p.mean();
    return p + n * k;
  }

  dump(x: string) {
    const k = this.k.mean();
    const p = this.p.mean();
    return `${k}.${x}+${p}`;
  }

}

/* --------------------------------------------------------------------------*/
/* ---  Sizing Component                                                  ---*/
/* --------------------------------------------------------------------------*/

export const WSIZER = new FontSizer(7, 6);
export const HSIZER = new FontSizer(14, 6);

export interface SizedAreaProps {
  cols: number;
  rows: number;
  children?: React.ReactNode;
}

export function SizedArea(props: SizedAreaProps) {
  const { rows, cols, children } = props;
  const refSizer = React.useCallback(
    (ref: null | HTMLDivElement) => {
      if (ref) {
        const r = ref.getBoundingClientRect();
        WSIZER.push(cols, r.width);
        HSIZER.push(rows, r.height);
      }
    }, [rows, cols],
  );
  return (
    <div
      ref={refSizer}
      className="eva-sized-area dome-text-cell"
    >
      {children}
    </div>
  );
}

/* --------------------------------------------------------------------------*/
