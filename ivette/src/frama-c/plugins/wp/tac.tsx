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

import React, { Fragment } from 'react';
import { classes } from 'dome/misc/utils';
import { Icon } from 'dome/controls/icons';
import { IconButton } from 'dome/controls/buttons';
import { Item, Descr, LabelProps } from 'dome/controls/labels';
import { Vbox, Hbox, Filler } from 'dome/layout/boxes';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import * as TAC from 'frama-c/plugins/wp/api/tac';

type Goal = WP.goal | undefined;
type Node = TIP.node | undefined;
type Tactic = TAC.tactic | undefined;

/* -------------------------------------------------------------------------- */
/* --- Apply Tactics                                                      --- */
/* -------------------------------------------------------------------------- */

async function applyTactic(tactic: Tactic): Promise<void> {
  if (tactic) {
    Server.send(TAC.applyTactic, tactic);
  }
}

/* -------------------------------------------------------------------------- */
/* --- Tactical Item                                                      --- */
/* -------------------------------------------------------------------------- */

interface TacticSelection {
  goal: Goal;
  node: Node;
  selected: Tactic;
  setSelected: (tac: Tactic) => void;
}

interface TacticItemProps extends TAC.tacticalData, TacticSelection {}

function TacticItem(props: TacticItemProps): JSX.Element | null {
  const { id: tactic, status, selected, setSelected } = props;
  if (status === 'NotApplicable') return null;
  const ready = status === 'Applicable';
  const isSelected = selected === tactic;
  const onSelect = (): void => setSelected(tactic);
  const onPlay = (): void => { if (ready) applyTactic(tactic); };
  const className = classes(
    'dome-color-frame wp-tactical-item',
    isSelected && 'selected',
  );
  return (
    <Hbox
      className={className}
      onClick={onSelect}
      onDoubleClick={onPlay}
    >
      <Item
        className='wp-tactical-cell' {...props}/>
      <IconButton
        icon='MEDIA.PLAY'
        title='Apply Tactic'
        kind='positive'
        enabled={ready}
        onClick={onPlay} />
    </Hbox>
  );
}

/* -------------------------------------------------------------------------- */
/* --- All Tactics View                                                   --- */
/* -------------------------------------------------------------------------- */

export function Tactics(props: TacticSelection): JSX.Element {
  const { node } = props;
  const tactics = States.useSyncArrayData(TAC.tactical);
  States.useRequest(TAC.configureTactics, node);
  const items =
    node
    ? tactics.map(tac => <TacticItem key={tac.id} {...props} {...tac} />)
    : null;
  return <Vbox className='wp-tactical-view dome-color-frame'>{items}</Vbox>;
}

/* -------------------------------------------------------------------------- */
/* --- Tactical Parameter                                                 --- */
/* -------------------------------------------------------------------------- */

interface ParameterProps extends TAC.parameter {
  node: TIP.node;
  tactic: TAC.tactic;
}

function CheckBox(props: ParameterProps): JSX.Element
{
  const { id: param, node, tactic, label, title, value } = props;
  const active = value === true;
  const onClick = (): void => {
    Server.send(TAC.setParameter, { node, tactic, param, value: !active });
  };
  return (
    <Item
      label={label}
      title={title}
      onClick={onClick} >
      <Icon id={active ? 'SWITCH.ON' : 'SWITCH.OFF'} />
    </Item>
  );
}

function Parameter(props: ParameterProps): JSX.Element | null
{
  switch(props.kind) {
    case 'checkbox':
      return <CheckBox {...props} />;
    default:
      return null;
  }
}

/* -------------------------------------------------------------------------- */
/* --- Tactical Configuration                                             --- */
/* -------------------------------------------------------------------------- */

const noTactic: TAC.tacticalData = {
  ...TAC.tacticalDataDefault,
  status: 'NotApplicable'
};

function useTactic(selected: Tactic): TAC.tacticalData {
  const data = States.useSyncArrayElt(TAC.tactical, selected);
  return data ?? noTactic;
}

function getStatusLabel(tactical: TAC.tacticalData): LabelProps {
  const { status, error, params } = tactical;
  if (error)
    return { icon: 'WARNING', kind: 'warning', label: error };
  if (status === 'NotConfigured')
    return { icon: 'WARNING', kind: 'default', label: 'Missing fields' };
  if (params.length)
    return { icon: 'CHECK', kind: 'positive', label: 'Configured' };
  return { icon: 'CHECK', kind: 'positive', label: 'Ready' };
}

export function ConfigureTactic(props: TacticSelection): JSX.Element {
  const { node, selected: tactic, setSelected } = props;
  const tactical = useTactic(tactic);
  const { status, label, title, params } = tactical;
  const display = !!tactic && status !== 'NotApplicable';
  const descr = getStatusLabel(tactical);
  const onClose = (): void => setSelected(undefined);
  const onPlay = (): void => { return; };
  const parameters =
    (node && tactic)
    ? params.map((prm: TAC.parameter) =>
      <Parameter key={prm.id} node={node} tactic={tactic} {...prm}/>
    ) : null;
  return (
    <Hbox
      className='dome-xToolBar dome-color-frame'
      display={display}
    >
      <Item
        key='tactic'
        className='wp-config-tactic'
        icon='TUNINGS' label={label} />
      <Fragment key='params'>{parameters}</Fragment>
      <Filler key='filler'/>
      <Descr key='info' icon='CIRC.INFO' label={title} />
      <Descr key='descr' {...descr} />
      <IconButton
        key='play'
        icon='MEDIA.PLAY'
        kind='positive'
        title='Apply Tactic'
        enabled={status==='Applicable'}
        onClick={onPlay} />
      <IconButton
        key='close'
        icon='CIRC.CLOSE'
        onClick={onClose}
        title='Close Tactic Configuration Panel' />
    </Hbox>
  );
}

/* -------------------------------------------------------------------------- */
