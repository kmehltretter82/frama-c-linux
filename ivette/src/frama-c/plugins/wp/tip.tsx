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
import { ToolBar, Select, Filler, Button } from 'dome/frame/toolbars';
import { Hfill, Vfill, Vbox, Overlay } from 'dome/layout/boxes';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';

import { getStatus } from './goals';
import { GoalView } from './seq';
import { Provers, Tactics, ConfigureTactic } from './tac';

/* -------------------------------------------------------------------------- */
/* --- Sequent Printing Modes                                             --- */
/* -------------------------------------------------------------------------- */

type Node = TIP.node | undefined;
type Prover = WP.prover | undefined;
type Tactic = TIP.tactic | undefined;

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
      className='wp-printer-field wp-printer-select'
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
      className='wp-printer-field wp-printer-select'
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
/* --- Node Path                                                          --- */
/* -------------------------------------------------------------------------- */

interface NodeProps {
  node: TIP.node;
  current: Node;
  parent?: boolean;
}

function Node(props: NodeProps): JSX.Element
{
  const cellRef = React.useRef<HTMLLabelElement>(null);
  const { node, parent } = props;
  const current = node === props.current;
  const debug = `#${node}`;
  const {
    title=debug, child='Script', header=debug,
    proved=false, pending=0, size=0
  } = States.useRequest( TIP.getNodeInfos, node, { pending: null } ) ?? {};
  const elt = cellRef.current;
  React.useEffect(() => {
    if (current && elt) elt.scrollIntoView();
  }, [elt, current]);
  const className = classes(
    'wp-navbar-node',
    parent && 'parent',
    current && 'current',
    !parent && !current && 'child',
  );
  const icon =
    current
    ? (parent ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT')
    : (parent ? 'ANGLE.DOWN' : 'ANGLE.RIGHT');
  const kind = proved ? 'positive' : (parent ? 'default' : 'warning');
  const nodeName = parent ? `${child}: ${header}` : child;
  const nodeRest = size <= 1 ? '?' : `${pending}/${size}`;
  const nodeFull = size <= 1 ? nodeName : `${nodeName} (${size})`;
  const nodeLabel = proved ? nodeFull : `${nodeName} (${nodeRest})`;
  const proofState =
    proved ? 'proved' :
    pending < size ? `pending ${pending}/${size}` : 'unproved';
  const fullTitle = `${title} (${proofState})`;
  const onSelection = (): void => { Server.send(TIP.goToNode, node); };
  return (
    <Cell
      ref={cellRef} className={className}
      icon={icon} kind={kind}
      label={nodeLabel}
      title={fullTitle}
      onClick={onSelection}
    />
  );
}

interface NavBarProps {
  above: TIP.node[];
  below: TIP.node[];
  current: Node;
}

function NavBar(props: NavBarProps): JSX.Element {
  const { current } = props;
  const parents = props.above.map(n => (
    <Node key={n} node={n} parent current={current} />
  )).reverse();
  const children = props.below.map(n => (
    <Node key={n} node={n} current={current} />
  ));
  return (
    <Vbox className='wp-navbar'>
      <Vbox>
        {parents}
        {children}
      </Vbox>
    </Vbox>
  );
}

/* -------------------------------------------------------------------------- */
/* --- TIP View                                                           --- */
/* -------------------------------------------------------------------------- */

export interface TIPProps {
  display: boolean;
  goal: WP.goal | undefined;
  onClose: () => void;
}

export function TIPView(props: TIPProps): JSX.Element {
  const { display, goal, onClose } = props;
  const infos =
    States.useSyncArrayElt( WP.goals, goal ) ?? WP.goalsDataDefault;
  const {
    current, above=[], below=[], index=-1, pending=0, tactic: nodeTactic
  } = States.useRequest( TIP.getProofStatus, goal, { pending: null } ) ?? {};
  const [ tactic, setTactic ] = React.useState<Tactic>();
  const [ prover, setProver ] = React.useState<Prover>();
  const [ autofocus, setAF ] = Dome.useBoolSettings('wp.tip.autofocus', true);
  const [ memory, setMEM ] = Dome.useBoolSettings('wp.tip.unmangled', true);
  const [ iformat, setIformat ] = Dome.useWindowSettings<TIP.iformat>(
    'wp.tip.iformat', TIP.jIformat, 'dec'
  );
  const [ rformat, setRformat ] = Dome.useWindowSettings<TIP.rformat>(
    'wp.tip.rformat', TIP.jRformat, 'ratio'
  );
  const locked = nodeTactic !== undefined;
  const configuredTactic = nodeTactic ?? tactic;
  const onSelectedProver = React.useCallback((prv) => {
    setTactic(undefined);
    setProver(prv);
  }, []);
  const onSelectedTactic = React.useCallback((tac) => {
    setTactic(tac);
    setProver(undefined);
  }, []);
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
        <Button
          kind='warning'
          icon='EJECT'
          title='Close proof transformer'
          onClick={onClose} />
      </ToolBar>
      <Hfill>
        <NavBar
          above={above}
          below={below}
          current={current}
        />
        <Vfill className='dome-positionned'>
          <Overlay display className='wp-printer'>
            <Icon
              id='LOCK'
              title='Tactical Selection Locked'
              className='wp-printer-locked'
              display={locked} />
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
            locked={locked}
            autofocus={autofocus}
            unmangled={!memory}
            iformat={iformat}
            rformat={rformat}
          />
        </Vfill>
        <Vbox className='wp-sidebar-view dome-color-frame'>
          <Provers
            node={current}
            selected={prover}
            setSelected={onSelectedProver}
          />
          <Tactics
            goal={goal}
            node={current}
            locked={locked}
            selected={configuredTactic}
            setSelected={onSelectedTactic}
          />
        </Vbox>
      </Hfill>
      <ConfigureTactic
        goal={goal}
        node={current}
        locked={locked}
        selected={configuredTactic}
        setSelected={onSelectedTactic}
      />
    </Vfill>
  );
}

/* -------------------------------------------------------------------------- */
