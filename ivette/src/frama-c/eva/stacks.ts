// --------------------------------------------------------------------------
// --- CallStacks
// --------------------------------------------------------------------------

import * as Server from 'frama-c/server';
import * as Values from 'frama-c/api/plugins/eva/values';

import { StateCallbacks } from './cells';

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
// --- CallStacks Cache
// --------------------------------------------------------------------------

export class StacksCache {

  private readonly state: StateCallbacks;
  private readonly stacks = new Map<string, callstacks>();
  private readonly calls = new Map<Values.callstack, Callsite[]>();

  // --------------------------------------------------------------------------
  // --- LifeCycle
  // --------------------------------------------------------------------------

  constructor(state: StateCallbacks) {
    this.state = state;
  }

  clear() {
    this.stacks.clear();
  }

  // --------------------------------------------------------------------------
  // --- Getters
  // --------------------------------------------------------------------------

  getStacks(stmt: string): callstacks {
    const cs = this.stacks.get(stmt);
    if (cs !== undefined) return cs;
    this.stacks.set(stmt, []);
    this.requestCallstacks(stmt);
    return [];
  }

  getCalls(cs: Values.callstack): Callsite[] {
    const fs = this.calls.get(cs);
    if (fs !== undefined) return fs;
    this.calls.set(cs, []);
    this.requestCalls(cs);
    return [];
  }

  // --------------------------------------------------------------------------
  // --- Fetchers
  // --------------------------------------------------------------------------

  private requestCallstacks(stmt: string) {
    Server
      .send(Values.getCallstacks, stmt)
      .then((cs: callstacks) => {
        this.stacks.set(stmt, cs);
        this.state.forceLayout();
      });
  }

  private requestCalls(cs: Values.callstack) {
    Server
      .send(Values.getCallstackInfo, cs)
      .then((calls) => {
        this.calls.set(cs, calls);
        this.state.forceUpdate();
      });
  }

}

// --------------------------------------------------------------------------
