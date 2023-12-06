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
import { classes } from 'dome/misc/utils';
import { IconButton } from 'dome/controls/buttons';
import { Item, Descr, LabelProps } from 'dome/controls/labels';
import { Vbox, Hbox, Filler } from 'dome/layout/boxes';
import * as States from 'frama-c/states';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import * as TAC from 'frama-c/plugins/wp/api/tac';

type Node = TIP.node | undefined;
type Tactic = TAC.tactic | undefined;

/* -------------------------------------------------------------------------- */
/* --- Tactical Item                                                      --- */
/* -------------------------------------------------------------------------- */

interface TacticItemProps extends TAC.tacticalData {
  node: Node;
  selected: Tactic;
  setSelected: (tac: Tactic) => void;
}

function TacticItem(props: TacticItemProps): JSX.Element | null {
  const { id, status, selected, setSelected } = props;
  if (status === 'NotApplicable') return null;
  const onSelect = (): void => setSelected(id);
  const onPlay = (): void => { return; };
  const className = classes(
    'dome-color-frame wp-tactical-item',
    selected===id && 'selected',
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
        enabled={status==='Applicable'}
        onClick={onPlay} />
    </Hbox>
  );
}

/* -------------------------------------------------------------------------- */
/* --- All Tactics View                                                   --- */
/* -------------------------------------------------------------------------- */

export interface TacticsProps {
  node: Node;
  selected: Tactic;
  setSelected: (tac: Tactic) => void;
}

export function Tactics(props: TacticsProps): JSX.Element {
  const { node, selected, setSelected } = props;
  const tactics = States.useSyncArrayData(TAC.tactical);
  States.useRequest(TAC.configureTactics, node);
  return (
    <Vbox className='wp-tactical-view dome-color-frame'>
      {tactics.map(tac => (
        <TacticItem
          key={tac.id}
          node={node}
          selected={selected}
          setSelected={setSelected}
          {...tac} />
      ))}
    </Vbox>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Tactical Parameter                                                 --- */
/* -------------------------------------------------------------------------- */

interface ParameterProps extends TAC.parameter {
  node: Node;
  tactic: Tactic;
}

function CheckBox(props: ParameterProps): JSX.Element
{
  const { label, title, value } = props;
  return (
    <Item
      icon={ value === true ? 'SWITCH.ON' : 'SWITCH.OFF' }
      label={label}
      title={title}
    />
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
  const { status, error } = tactical;
  if (error)
    return { icon: 'WARNING', kind: 'warning', label: error };
  if (status === 'NotConfigured')
    return { icon: 'WARNING', kind: 'default', label: 'Missing fields' };
  return { icon: 'CHECK', kind: 'positive', label: 'Configured' };
}

export function Configure(props: TacticsProps): JSX.Element {
  const { node, selected, setSelected } = props;
  const tactical = useTactic(selected);
  const { status, label, title, params } = tactical;
  const display = !!selected && status !== 'NotApplicable';
  const descr = getStatusLabel(tactical);
  const onClose = (): void => setSelected(undefined);
  const onPlay = (): void => { return; };
  const parameters = params.map((prm: TAC.parameter) => (
    <Parameter key={prm.id} node={node} tactic={selected} {...prm}/>
  ));
  return (
    <Hbox display={display}>
      <Item key='tactic' icon='TUNINGS'>Tactic: {label}</Item>
      <>{parameters}</>
      <Filler/>
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
