/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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

import React from 'react';
import { Cell } from 'dome/controls/labels';
import { Vfill, Hbox } from 'dome/layout/boxes';
import { MarkDecoration, Decorations, TextView } from 'dome/text/richtext';
import * as States from 'frama-c/states';
import * as RichText from 'frama-c/richtext';
import type { text } from 'frama-c/kernel/api/data';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import { getStatus } from './goals';

/* -------------------------------------------------------------------------- */
/* --- Sequent Decorations                                                --- */
/* -------------------------------------------------------------------------- */

type Node = TIP.node | undefined;

class Sequent {
  private readonly contents: string;
  private readonly style: MarkDecoration[];

  constructor(jtext: text) {
    this.contents = RichText.textToString(jtext);
    this.style = [];
    const addStyle = (tg: RichText.Tag, className: string): void => {
      const { offset, endOffset } = tg;
      const length = endOffset - offset;
      this.style.push({ className, offset, length });
    };
    const filter = (t: RichText.Tag): boolean => {
      switch(t.tag) {
        case 'wp:comment':
        case 'wp:property':
          addStyle(t, 'cm-comment');
          return false;
        case 'wp:stmt':
        case 'wp:clause':
        case 'wp:warning':
          addStyle(t, 'cm-keyword');
          return false;
        case 'wp:label':
          addStyle(t, 'cm-def');
          return false;
        case 'wp:var':
          addStyle(t, 'cm-type');
          return false;
        case 'wp:focus':
          addStyle(t, 'cm-hovered');
          return false;
        case 'wp:target':
          addStyle(t, 'cm-selected-code');
          return false;
      }
      return t.tag.startsWith('#');
    };
    RichText.textToTags(jtext, filter);
  }

  get text(): string {
    return this.contents;
  }

  get decorations(): Decorations {
    return this.style;
  }

}

/* -------------------------------------------------------------------------- */
/* --- Sequent View                                                       --- */
/* -------------------------------------------------------------------------- */

interface GoalViewProps {
  node: Node;
}

function GoalView(props: GoalViewProps): JSX.Element {
  const { node } = props;
  const jtext = States.useRequest(TIP.printSequent, { node }) ?? null;
  const sequent = React.useMemo(() => new Sequent(jtext), [jtext]);
  return (
    <TextView
      readOnly
      text={sequent.text}
      decorations={sequent.decorations}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* --- TIP View                                                           --- */
/* -------------------------------------------------------------------------- */

interface ProofState {
  current: Node;
  index: number;
  pending: number;
}

function useProofState(target: WP.goal | undefined): ProofState {
  const DefaultProofState: ProofState = {
    current: undefined, index: 0, pending: 0
  };
  return States.useRequest(
    TIP.getProofState,
    target,
    { onError: DefaultProofState }
  ) ?? DefaultProofState;
}

function useTarget(target: WP.goal | undefined) : WP.goalsData {
  return States.useSyncArrayElt( WP.goals, target ) ?? WP.goalsDataDefault;
}

export interface TIPProps {
  display: boolean;
  goal: WP.goal | undefined;
}

export function TIPView(props: TIPProps): JSX.Element {
  const { display, goal } = props;
  const infos = useTarget(goal);
  const { current, index, pending } = useProofState(goal);
  return (
    <Vfill display={display}>
      <Hbox>
        <Cell
          icon='HOME'
          label={infos.wpo} title='Goal identifier' />
        <Cell
          icon='CODE'
          display={0 <= index && index < pending}
          label={`${index}/${pending}`} title='Pending proof nodes'/>
        <Cell {...getStatus(infos)}/>
      </Hbox>
      <GoalView node={current} />
    </Vfill>
  );
}

/* -------------------------------------------------------------------------- */
