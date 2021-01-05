// --------------------------------------------------------------------------
// --- CallStacks
// --------------------------------------------------------------------------

import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/api/kernel/ast';
import * as Values from 'frama-c/api/plugins/eva/values';

import { ModelCallbacks } from './cells';

// --------------------------------------------------------------------------
// --- Callstack infos
// --------------------------------------------------------------------------

export type callstacks = Values.callstack[];
export interface Callsite {
  callee: string;
  caller?: string;
  stmt?: string;
  rank?: number;
}

// --------------------------------------------------------------------------
// --- CallStacks by Function
// --------------------------------------------------------------------------

interface StacksByFct {
  dirty: boolean;
  stacks: callstacks;
}

interface ProbeFct {
  fct: string;
  marker: Ast.marker;
}

// --------------------------------------------------------------------------
// --- CallStacks Cache
// --------------------------------------------------------------------------

export class StacksCache {

  private readonly model: ModelCallbacks;
  private readonly byFct = new Map<string, StacksByFct>();
  private readonly calls = new Map<Values.callstack, Callsite[]>();

  // --------------------------------------------------------------------------
  // --- LifeCycle
  // --------------------------------------------------------------------------

  constructor(state: ModelCallbacks) {
    this.model = state;
  }

  clear() {
    this.byFct.clear();
  }

  // --------------------------------------------------------------------------
  // --- Getters
  // --------------------------------------------------------------------------

  mergeStacksForFunction(fct: string) {
    const buffer = this.byFct.get(fct);
    if (buffer) buffer.dirty = true;
  }

  getStacksForProbe({ fct, marker }: ProbeFct): callstacks {
    const fs = this.byFct.get(fct);
    if (!fs) {
      this.byFct.set(fct, { dirty: true, stacks: [] });
      this.requestCallstacks(fct, [marker]);
    }
    return fs ? fs.stacks : [];
  }

  getStacksForFunction(fct: string, probes?: Ast.marker[]): callstacks {
    const fs = this.byFct.get(fct);
    if (!fs) this.byFct.set(fct, { dirty: false, stacks: [] });
    if (probes) {
      if (!fs || fs.dirty) this.requestCallstacks(fct, probes);
      if (fs && fs.dirty) fs.dirty = false;
    }
    return fs ? fs.stacks : [];
  }

  getCalls(cs: Values.callstack): Callsite[] {
    const fcs = this.calls.get(cs);
    if (fcs !== undefined) return fcs;
    this.calls.set(cs, []);
    this.requestCalls(cs);
    return [];
  }

  // --------------------------------------------------------------------------
  // --- Fetchers
  // --------------------------------------------------------------------------

  private requestCallstacks(fct: string, probes: Ast.marker[]) {
    Server
      .send(Values.getCallstacks, probes)
      .then((stacks: callstacks) => {
        this.byFct.set(fct, { dirty: false, stacks });
        this.model.forceLayout();
        this.model.forceUpdate();
      });
  }

  private requestCalls(cs: Values.callstack) {
    Server
      .send(Values.getCallstackInfo, cs)
      .then((calls) => {
        this.calls.set(cs, calls);
        this.model.forceUpdate();
      });
  }

}

// --------------------------------------------------------------------------
