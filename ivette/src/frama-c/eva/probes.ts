/* --------------------------------------------------------------------------*/
/* --- Probes                                                             ---*/
/* --------------------------------------------------------------------------*/

// Frama-C
import * as Server from 'frama-c/server';
import * as Values from 'frama-c/api/plugins/eva/values';
import * as Ast from 'frama-c/api/kernel/ast';

// Model
import { StateCallbacks } from './cells';

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
  readonly marker: Ast.marker;
  readonly state: StateCallbacks;
  transient = true;
  label?: string;
  code?: string;
  stmt?: string;
  rank?: number;
  minCols: number = LabelSize;
  maxCols: number = LabelSize;

  constructor(state: StateCallbacks, marker: Ast.marker) {
    this.marker = marker;
    this.state = state;
    this.requestProbeInfo = this.requestProbeInfo.bind(this);
    this.setPersistent = this.setPersistent.bind(this);
    this.setTransient = this.setTransient.bind(this);
  }

  requestProbeInfo() {
    Server
      .send(Values.getProbeInfo, this.marker)
      .then(({ code, stmt, rank }) => {
        this.code = code;
        this.stmt = stmt;
        this.rank = rank;
      })
      .catch(() => {
        this.code = '(error)';
      })
      .finally(this.state.forceUpdate);
  }

  // --------------------------------------------------------------------------
  // --- Internal State
  // --------------------------------------------------------------------------

  setPersistent() {
    if (this.transient && this.code) {
      this.transient = false;
      if (this.code.length > LabelSize)
        this.label = newLabel();
      this.state.forceLayout();
    }
  }

  setTransient() {
    if (!this.transient) {
      this.transient = true;
      if (this.label) {
        LabelRing.push(this.label);
        this.label = undefined;
      }
      this.state.forceLayout();
    }
  }

  // --------------------------------------------------------------------------
  // --- Ordering
  // --------------------------------------------------------------------------

  static order(p: Probe, q: Probe): number {
    const rp = p.rank ?? 0;
    const rq = q.rank ?? 0;
    if (rp < rq) return (-1);
    if (rp > rq) return (+1);
    if (p.transient && !q.transient) return (-1);
    if (!p.transient && q.transient) return (+1);
    if (p.marker < q.marker) return (-1);
    if (p.marker > q.marker) return (+1);
    return 0;
  }

}

/* --------------------------------------------------------------------------*/
