/* --------------------------------------------------------------------------*/
/* --- Probes                                                             ---*/
/* --------------------------------------------------------------------------*/

// Frama-C
import * as Server from 'frama-c/server';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values';

// Model
import { StateCallbacks, Size, EMPTY, LABEL } from './cells';

/* --------------------------------------------------------------------------*/
/* --- Probe Labelling                                                    ---*/
/* --------------------------------------------------------------------------*/

const Ka = 'A'.charCodeAt(0);
const Kz = 'Z'.charCodeAt(0);
const LabelRing: string[] = [];
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
  readonly marker: string;
  readonly state: StateCallbacks;
  transient = true;
  label?: string;
  code?: string;
  stmt?: string;
  rank?: number;
  layout: Size;
  summary: Size;

  constructor(state: StateCallbacks, marker: string) {
    this.marker = marker;
    this.state = state;
    this.layout = EMPTY;
    this.summary = EMPTY;
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

  setPersistent() {
    if (this.transient && this.code) {
      this.transient = false;
      if (this.code.length > LABEL)
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
