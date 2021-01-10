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
