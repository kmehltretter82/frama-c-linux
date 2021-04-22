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
  stmt?: Ast.marker;
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
    return this.summary.get(fct) ?? true;
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
