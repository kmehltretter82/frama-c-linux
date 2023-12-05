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
import * as Dome from 'dome';

import { json } from 'dome/data/json';
import { Cell } from 'dome/controls/labels';
import { ToolBar, Select, Filler } from 'dome/frame/toolbars';
import { Hfill, Vfill } from 'dome/layout/boxes';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';

import { getStatus } from './goals';
import { GoalView } from './seq';
import { Tactics } from './tac';

/* -------------------------------------------------------------------------- */
/* --- Sequent Printing Modes                                             --- */
/* -------------------------------------------------------------------------- */

type Focus = 'AUTOFOCUS' | 'FULLCONTEXT' | 'MEMORY' | 'RAW';

interface Selector<A> {
  value: A;
  setValue: (value: A) => void;
}

function jFocus(js: json): Focus {
  switch(js) {
    case 'AUTOFOCUS':
    case 'FULLCONTEXT':
    case 'MEMORY':
    case 'RAW':
      return (js as Focus);
    default:
      return 'AUTOFOCUS';
  }
}

function FocusSelector(props: Selector<Focus>): JSX.Element {
  const { value, setValue } = props;
  return (
    <Select
      value={value}
      title='Autofocus Mode'
      onChange={(v) => setValue(jFocus(v))}
    >
      <option value='AUTOFOCUS'>Auto Focus</option>
      <option value='FULLCONTEXT'>Full Context</option>
      <option value='MEMORY'>Memory Model</option>
      <option value='RAW'>Raw Proof</option>
    </Select>
  );
}

function IFormatSelector(props: Selector<TIP.iformat>): JSX.Element {
  const { value, setValue } = props;
  return (
    <Select
      value={value}
      title='Large Integers Format'
      onChange={(v) => setValue(TIP.jIformat(v))}
    >
      <option value='dec'>Int</option>
      <option value='hex'>Hex</option>
      <option value='bin'>Bin</option>
    </Select>
  );
}

function RFormatSelector(props: Selector<TIP.rformat>): JSX.Element {
  const { value, setValue } = props;
  return (
    <Select
      value={value}
      title='Floatting Point Constants Format'
      onChange={(v) => setValue(TIP.jRformat(v))}
    >
      <option value='ratio'>Real</option>
      <option value='float'>Float</option>
      <option value='double'>Double</option>
    </Select>
  );
}

/* -------------------------------------------------------------------------- */
/* --- TIP View                                                           --- */
/* -------------------------------------------------------------------------- */

interface ProofState {
  current: TIP.node | undefined;
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
  const [ focus, setFocus ] = Dome.useWindowSettings<Focus>(
    'wp.tip.focus', jFocus, 'AUTOFOCUS'
  );
  const [ iformat, setIformat ] = Dome.useWindowSettings<TIP.iformat>(
    'wp.tip.iformat', TIP.jIformat, 'dec'
  );
  const [ rformat, setRformat ] = Dome.useWindowSettings<TIP.rformat>(
    'wp.tip.rformat', TIP.jRformat, 'ratio'
  );
  const autofocus = focus === 'AUTOFOCUS' || focus === 'MEMORY';
  const unmangled = focus === 'MEMORY' || focus === 'RAW';
  return (
    <Vfill display={display}>
      <ToolBar>
        <Cell
          icon='HOME'
          label={infos.wpo} title='Goal identifier' />
        <Cell
          icon='CODE'
          display={0 <= index && index < pending && 1 < pending}
          label={`${index+1}/${pending}`} title='Pending proof nodes'/>
        <Cell {...getStatus(infos)}/>
        <Filler/>
        <FocusSelector value={focus} setValue={setFocus}/>
        <IFormatSelector value={iformat} setValue={setIformat}/>
        <RFormatSelector value={rformat} setValue={setRformat}/>
      </ToolBar>
      <Hfill>
        <Vfill>
          <GoalView
            node={current}
            autofocus={autofocus}
            unmangled={unmangled}
            iformat={iformat}
            rformat={rformat}
          />
        </Vfill>
        <Tactics node={current} />
      </Hfill>
    </Vfill>
  );
}

/* -------------------------------------------------------------------------- */
