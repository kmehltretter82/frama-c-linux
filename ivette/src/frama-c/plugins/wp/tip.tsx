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

import { classes } from 'dome/misc/utils';
import { Icon } from 'dome/controls/icons';
import { Cell, Item } from 'dome/controls/labels';
import { ToolBar, Select, Filler } from 'dome/frame/toolbars';
import { Hfill, Vfill, Overlay } from 'dome/layout/boxes';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import type { tactic } from 'frama-c/plugins/wp/api/tac';

import { getStatus } from './goals';
import { GoalView } from './seq';
import { Tactics, ConfigureTactic } from './tac';

/* -------------------------------------------------------------------------- */
/* --- Sequent Printing Modes                                             --- */
/* -------------------------------------------------------------------------- */

type Tactic = tactic | undefined;

interface Selector<A> {
  value: A;
  setValue: (value: A) => void;
}

interface BoolSelector extends Selector<boolean> {
  label: string;
  title: string;
}

function AFormatSelector(props: BoolSelector): JSX.Element {
  const { value, setValue } = props;
  const className = classes(
    'wp-printer-field wp-printer-button',
    value && 'selected'
  );
  return (
    <Item
      className={className}
      label={props.label}
      title={props.title}
      onClick={() => setValue(!value)}
    >
      <Icon id={value ? 'SWITCH.ON' : 'SWITCH.OFF'} />
    </Item>
  );
}

function IFormatSelector(props: Selector<TIP.iformat>): JSX.Element {
  const { value, setValue } = props;
  return (
    <Select
      className="wp-printer-field wp-printer-select"
      value={value}
      title='Large integers format.'
      onChange={(v) => setValue(TIP.jIformat(v))}
    >
      <option value='dec' title='Integer'>int</option>
      <option value='hex' title='Hex.'>hex</option>
      <option value='bin' title='Binary'>bin</option>
    </Select>
  );
}

function RFormatSelector(props: Selector<TIP.rformat>): JSX.Element {
  const { value, setValue } = props;
  return (
    <Select
      className="wp-printer-field wp-printer-select"
      value={value}
      title='Floatting point format.'
      onChange={(v) => setValue(TIP.jRformat(v))}
    >
      <option value='ratio' title='Rational fraction'>frac</option>
      <option value='float' title='IEEE Float 32-bits'>f32</option>
      <option value='double' title='IEEE Float 64-bits'>f64</option>
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

export interface TIPProps {
  display: boolean;
  goal: WP.goal | undefined;
}

export function TIPView(props: TIPProps): JSX.Element {
  const { display, goal } = props;
  const infos =
    States.useSyncArrayElt( WP.goals, goal ) ?? WP.goalsDataDefault;
  const { current, index, pending } = useProofState(goal);
  const [selected, setSelected] = React.useState<Tactic>();
  const [ autofocus, setAF ] = Dome.useBoolSettings('wp.tip.autofocus', true);
  const [ memory, setMEM ] = Dome.useBoolSettings('wp.tip.unmangled', true);
  const [ iformat, setIformat ] = Dome.useWindowSettings<TIP.iformat>(
    'wp.tip.iformat', TIP.jIformat, 'dec'
  );
  const [ rformat, setRformat ] = Dome.useWindowSettings<TIP.rformat>(
    'wp.tip.rformat', TIP.jRformat, 'ratio'
  );
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
      </ToolBar>
      <Hfill>
        <Vfill className="dome-positionned">
          <Overlay display className="wp-printer">
            <AFormatSelector
              value={autofocus} setValue={setAF}
              label='AF' title='Autofocus mode.' />
            <AFormatSelector
              value={memory} setValue={setMEM}
              label='MEM' title='Memory model internals.' />
            <IFormatSelector value={iformat} setValue={setIformat}/>
            <RFormatSelector value={rformat} setValue={setRformat}/>
          </Overlay>
          <GoalView
            node={current}
            autofocus={autofocus}
            unmangled={!memory}
            iformat={iformat}
            rformat={rformat}
          />
        </Vfill>
        <Tactics
          goal={goal}
          node={current}
          selected={selected}
          setSelected={setSelected}
        />
      </Hfill>
      <ConfigureTactic
        goal={goal}
        node={current}
        selected={selected}
        setSelected={setSelected}
      />
    </Vfill>
  );
}

/* -------------------------------------------------------------------------- */
