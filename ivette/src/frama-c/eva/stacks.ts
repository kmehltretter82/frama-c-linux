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

// --------------------------------------------------------------------------
// --- CallStacks Cache
// --------------------------------------------------------------------------

export class StacksCache {

  private readonly state: StateCallbacks;
  private readonly stacks = new Map<string, callstacks>();

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

}

// --------------------------------------------------------------------------
