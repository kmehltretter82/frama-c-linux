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

function equalSite(a: Callsite, b: Callsite): boolean {
  return a.stmt === b.stmt && a.callee === b.callee;
}

// --------------------------------------------------------------------------
// --- CallStacks Cache
// --------------------------------------------------------------------------

export class StacksCache {

  private readonly model: ModelCallbacks;
  private readonly stacks = new Map<string, callstacks>();
  private readonly summary = new Map<string, boolean>();
  private readonly calls = new Map<Values.callstack, Callsite[]>();

  // --------------------------------------------------------------------------
  // --- LifeCycle
  // --------------------------------------------------------------------------

  constructor(state: ModelCallbacks) {
    this.model = state;
  }

  clear() {
    this.stacks.clear();
    this.calls.clear();
  }

  // --------------------------------------------------------------------------
  // --- Getters
  // --------------------------------------------------------------------------

  getSummary(fct: string): boolean {
    return this.summary.get(fct) || false;
  }

  setSummary(fct: string, s: boolean) {
    this.summary.set(fct, s);
    this.model.forceLayout();
  }

  getStacks(...markers: Ast.marker[]): callstacks {
    if (markers.length === 0) return [];
    const key = markers.join('$');
    const cs = this.stacks.get(key);
    if (cs !== undefined) return cs;
    this.stacks.set(key, []);
    this.requestStacks(key, markers);
    return [];
  }

  getCalls(cs: Values.callstack): Callsite[] {
    const fs = this.calls.get(cs);
    if (fs !== undefined) return fs;
    this.calls.set(cs, []);
    this.requestCalls(cs);
    return [];
  }

  aligned(a: Values.callstack, b: Values.callstack): boolean {
    if (a === b) return true;
    const ca = this.getCalls(a);
    const cb = this.getCalls(b);
    let ka = ca.length - 1;
    let kb = cb.length - 1;
    while (ka >= 0 && kb >= 0 && equalSite(ca[ka], cb[kb])) {
      --ka;
      --kb;
    }
    return ka < 0 || kb < 0;
  }

  // --------------------------------------------------------------------------
  // --- Fetchers
  // --------------------------------------------------------------------------

  private requestStacks(key: string, markers: Ast.marker[]) {
    Server
      .send(Values.getCallstacks, markers)
      .then((stacks: callstacks) => {
        this.stacks.set(key, stacks);
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
