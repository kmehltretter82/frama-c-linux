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
/* --- Ivette Extensions                                                  ---*/
/* --------------------------------------------------------------------------*/

import React from 'react';
import * as Dome from 'dome';
import { Hint } from 'dome/frame/toolbars';

/* --------------------------------------------------------------------------*/
/* --- Search Hints                                                       ---*/
/* --------------------------------------------------------------------------*/

export interface HintCallback {
  (): void;
}

export interface SearchHint extends Hint<HintCallback> {
  rank?: number;
}

function bySearchHint(a: SearchHint, b: SearchHint) {
  const ra = a.rank ?? 0;
  const rb = b.rank ?? 0;
  if (ra < rb) return -1;
  if (ra > rb) return +1;
  return 0;
}

export interface SearchEngine {
  id: string;
  search: (pattern: string) => Promise<SearchHint[]>;
}

const NEWHINTS = new Dome.Event('ivette.hints');
const HINTLOOKUP = new Map<string, SearchEngine>();
const HINTS = new Map<string, SearchHint[]>();
let CURRENT = '';

export function updateHints() {
  if (CURRENT !== '')
    NEWHINTS.emit();
}

export function registerHints(E: SearchEngine) {
  HINTLOOKUP.set(E.id, E);
}

export function searchHints(pattern: string) {
  if (pattern === '') {
    CURRENT = '';
    HINTS.clear();
    NEWHINTS.emit();
  } else {
    const REF = pattern;
    CURRENT = pattern;
    HINTLOOKUP.forEach((E: SearchEngine) => {
      E.search(REF).then((hs) => {
        if (REF === CURRENT) {
          HINTS.set(E.id, hs);
          NEWHINTS.emit();
        }
      }).catch(() => {
        if (REF === CURRENT) {
          HINTS.delete(E.id);
          NEWHINTS.emit();
        }
      });
    });
  }
}

export function onSearchHint(h: SearchHint) {
  h.value();
}

export function useSearchHints() {
  const [hints, setHints] = React.useState<SearchHint[]>([]);
  Dome.useEvent(NEWHINTS, () => {
    let hs: SearchHint[] = [];
    HINTS.forEach((rhs) => { hs = hs.concat(rhs); });
    setHints(hs.sort(bySearchHint));
  });
  return hints;
}

/* --------------------------------------------------------------------------*/
/* --- Extension Elements                                                 ---*/
/* --------------------------------------------------------------------------*/

const UPDATED = new Dome.Event('ivette.updated');

export interface ElementProps {
  id: string;
  rank?: number;
  children?: React.ReactNode;
}

function byPanel(p: ElementProps, q: ElementProps) {
  const rp = p.rank ?? 0;
  const rq = q.rank ?? 0;
  if (rp < rq) return -1;
  if (rp > rq) return +1;
  const ip = p.id;
  const iq = q.id;
  if (ip < iq) return -1;
  if (ip > iq) return +1;
  return 0;
}

export class ElementRack {

  private readonly items = new Map<string, ElementProps>();

  register(elt: ElementProps) {
    this.items.set(elt.id, elt);
    UPDATED.emit();
  }

  render() {
    const panels: ElementProps[] = [];
    this.items.forEach((p) => { if (p.children) { panels.push(p); } });
    const contents = panels.sort(byPanel).map((p) => p.children);
    return <>{React.Children.toArray(contents)}</>;
  }

}

export function useRack(E: ElementRack) {
  Dome.useUpdate(UPDATED);
  return E.render();
}

export const SIDEBAR = new ElementRack();
export const TOOLBAR = new ElementRack();
export const STATUSBAR = new ElementRack();

export function Sidebar() { return useRack(SIDEBAR); }
export function Toolbar() { return useRack(TOOLBAR); }
export function Statusbar() { return useRack(STATUSBAR); }

/* --------------------------------------------------------------------------*/
