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

/* --------------------------------------------------------------------------*/
/* --- Probes                                                             ---*/
/* --------------------------------------------------------------------------*/

// Frama-C
import * as Server from 'frama-c/server';
import * as Values from 'frama-c/api/plugins/eva/values';
import * as Ast from 'frama-c/api/kernel/ast';

// Model
import { ModelCallbacks } from './cells';

/* --------------------------------------------------------------------------*/
/* --- Probe Labelling                                                    ---*/
/* --------------------------------------------------------------------------*/

const Ka = 'A'.charCodeAt(0);
const Kz = 'Z'.charCodeAt(0);
const LabelRing: string[] = [];
const LabelSize = 12;
let La = Ka;
let Lk = 0;

function newLabel() {
  let lbl = LabelRing.shift();
  if (lbl) return lbl;
  const a = La;
  const k = Lk;
  lbl = String.fromCharCode(a);
  if (a < Kz) {
    La++;
  } else {
    La = Ka;
    Lk++;
  }
  return k > 0 ? lbl + k : lbl;
}

/* --------------------------------------------------------------------------*/
/* --- Probe State                                                        ---*/
/* --------------------------------------------------------------------------*/

export class Probe {

  // properties
  readonly fct: string;
  readonly marker: Ast.marker;
  readonly model: ModelCallbacks;
  next?: Probe;
  prev?: Probe;
  transient = true;
  loading = true;
  label?: string;
  code?: string;
  stmt?: string;
  rank?: number;
  minCols: number = LabelSize;
  maxCols: number = LabelSize;
  byCallstacks = false;
  zoomed = false;
  zoomable = false;
  effects = false;
  condition = false;

  constructor(state: ModelCallbacks, fct: string, marker: Ast.marker) {
    this.fct = fct;
    this.marker = marker;
    this.model = state;
    this.requestProbeInfo = this.requestProbeInfo.bind(this);
  }

  requestProbeInfo() {
    this.loading = true;
    this.label = '…';
    Server
      .send(Values.getProbeInfo, this.marker)
      .then(({ code, stmt, rank, effects, condition }) => {
        this.code = code;
        this.stmt = stmt;
        this.rank = rank;
        this.label = undefined;
        this.effects = effects;
        this.condition = condition;
        this.loading = false;
        this.updateLabel();
      })
      .catch(() => {
        this.code = '(error)';
        this.stmt = undefined;
        this.rank = undefined;
        this.label = undefined;
        this.effects = false;
        this.condition = false;
        this.loading = false;
      })
      .finally(this.model.forceLayout);
  }

  // --------------------------------------------------------------------------
  // --- Internal State
  // --------------------------------------------------------------------------

  setPersistent() { this.updateTransient(false); }
  setTransient() { this.updateTransient(true); }

  private updateLabel() {
    const { transient, label, code } = this;
    if (transient && label) {
      LabelRing.push(label);
      this.label = undefined;
    }
    if (!transient && !label && code && code.length > LabelSize)
      this.label = newLabel();
  }

  private updateTransient(tr: boolean) {
    if (this.transient !== tr) {
      this.transient = tr;
      this.updateLabel();
      this.model.forceLayout();
    }
  }

  setByCallstacks(byCS: boolean) {
    if (byCS !== this.byCallstacks) {
      this.byCallstacks = byCS;
      if (byCS) this.setPersistent();
      this.model.forceLayout();
    }
  }

  setZoomed(zoomed: boolean) {
    if (zoomed !== this.zoomed) {
      this.zoomed = zoomed;
      this.model.forceLayout();
    }
  }

}

/* --------------------------------------------------------------------------*/
