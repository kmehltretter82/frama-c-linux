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
import { IconButton, Spinner, Select } from 'dome/controls/buttons';
import { Label, Item, Descr } from 'dome/controls/labels';
import { Vbox, Hbox, Filler } from 'dome/layout/boxes';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import * as TAC from 'frama-c/plugins/wp/api/tac';

type Goal = WP.goal | undefined;
type Node = TIP.node | undefined;
type Tactic = TIP.tactic | undefined;

/* -------------------------------------------------------------------------- */
/* --- Prover Feedback                                                    --- */
/* -------------------------------------------------------------------------- */

interface ProverProps {
  prover: WP.prover;
  result: WP.result | undefined;
}

function Prover(props : ProverProps): JSX.Element
{
  const { prover } = props;
  const { name, ident } = States.useRequest(WP.getProverInfo, prover) ?? {};
  const className = classes(
    'dome-color-frame wp-tactical-item',
    //isSelected && 'selected',
  );
  return (
    <Hbox className={className}>
      <Item
        className='wp-tactical-cell'
        label={name}
        title={ident}
      />
    </Hbox>
  );
}

export interface ProverSelection {
  node: Node;
}

export function Provers(props: ProverSelection): JSX.Element {
  const { node } = props;
  const { results=[] } = States.useRequest(TIP.getNodeInfos,node) ?? {};
  const [ provers=[] ] = States.useSyncState(WP.provers)
  const items = provers.map((prover) => {
    const res = results.find(([p]) => p == prover);
    const result = res ? res[1] : undefined;
    return <Prover key={prover} prover={prover} result={result} />
  });
  return <>{node ? items : null}</>;
}

/* -------------------------------------------------------------------------- */
/* --- Apply Tactics                                                      --- */
/* -------------------------------------------------------------------------- */

function applyTactic(tactic: Tactic): void {
  if (tactic) {
    Server.send(TAC.applyTactic, tactic);
  }
}

/* -------------------------------------------------------------------------- */
/* --- Tactical Item                                                      --- */
/* -------------------------------------------------------------------------- */

export interface TacticSelection {
  goal: Goal;
  node: Node;
  locked: boolean;
  selected: Tactic;
  setSelected: (tac: Tactic) => void;
}

interface TacticItemProps extends TAC.tacticalData, TacticSelection {}

function TacticItem(props: TacticItemProps): JSX.Element | null {
  const { id: tactic, status, locked, selected, setSelected } = props;
  if (status === 'NotApplicable') return null;
  const ready = !locked && status === 'Applicable';
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
      <Item className="wp-tactical-cell" {...props}/>
      <IconButton
        icon={locked ? 'LOCK' : 'MEDIA.PLAY'}
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
  const items =
    node
    ? tactics.map(tac => <TacticItem key={tac.id} {...props} {...tac} />)
    : null;
  return <>{items}</>;
}

/* -------------------------------------------------------------------------- */
/* --- Tactical Parameter                                                 --- */
/* -------------------------------------------------------------------------- */

interface ParameterProps extends TAC.parameter {
  node: TIP.node;
  locked: boolean;
  tactic: TIP.tactic;
}

function CheckBoxParam(props: ParameterProps): JSX.Element
{
  const { id: param, locked, node, tactic, label, title, value } = props;
  const active = value === true;
  const onClick = (): void => {
    if (!locked)
      Server.send(TAC.setParameter, { node, tactic, param, value: !active });
  };
  return (
    <Label
      className="wp-config-checkbox"
      label={label}
      title={title}
      onClick={onClick} >
      <Icon
        className="wp-config-switch"
        size={14}
        offset={-2}
        kind={locked ? 'disabled' : 'default'}
        id={active ? 'SWITCH.ON' : 'SWITCH.OFF'} />
    </Label>
  );
}

function SpinnerParam(props: ParameterProps): JSX.Element
{
  const {
    id: param, locked, node, tactic, label, title,
    vmin, vmax, vstep, value: jval
  } = props;
  const onChange = (value: number): void => {
    if (!locked)
      Server.send(TAC.setParameter, { node, tactic, param, value });
  };
  const value = typeof(jval)==='number' ? jval : undefined;
  return (
    <Label label={label} title={title}>
      <Spinner
        className="wp-config-field wp-config-spinner"
        value={value}
        vmin={vmin}
        vmax={vmax}
        vstep={vstep}
        disabled={locked}
        onChange={onChange}
      />
    </Label>
  );
}

function SelectorParam(props: ParameterProps): JSX.Element
{
  const {
    id: param, locked, node, tactic, label, title,
    value: jval, vlist=[]
  } = props;
  const value = typeof(jval) === 'string' ? jval : undefined;
  const options = vlist.map(({ id, label, title }) =>
    <option key={id} value={id} title={title}>{label}</option>
  );
  const onChange = (value: string | undefined): void => {
    if (!locked)
      Server.send(TAC.setParameter, { node, tactic, param, value });
  };
  return (
    <Label label={label} title={title}>
      <Select
        className="wp-config-field wp-config-select"
        value={value}
        disabled={locked}
        onChange={onChange}
      >{options}</Select>
    </Label>
  );
}

function Parameter(props: ParameterProps): JSX.Element | null
{
  if (!props.enabled) return null;
  switch(props.kind) {
    case 'checkbox':
      return <CheckBoxParam {...props} />;
    case 'spinner':
      return <SpinnerParam {...props} />;
    case 'selector':
      return <SelectorParam {...props} />;
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

interface StatusDescr {
  icon: string;
  kind: 'warning' | 'positive' | 'default';
  label: string;
}

const Locked: StatusDescr = {
  icon: 'CHECK',
  kind: 'default',
  label: 'Applied',
};

function getStatusDescription(tactical: TAC.tacticalData): StatusDescr {
  const { status, error, params } = tactical;
  if (error)
    return { icon: 'WARNING', kind: 'warning', label: error };
  if (status === 'NotConfigured')
    return { icon: 'WARNING', kind: 'warning', label: 'Missing fields' };
  if (params.length)
    return { icon: 'CHECK', kind: 'positive', label: 'Configured' };
  return { icon: 'CHECK', kind: 'positive', label: 'Ready' };
}

export function ConfigureTactic(props: TacticSelection): JSX.Element {
  const { node, locked, selected: tactic, setSelected } = props;
  const tactical = useTactic(tactic);
  States.useRequest(TAC.configureTactics, node);
  const { status, label, title, params } = tactical;
  const isReady = !locked && status==='Applicable';
  const display = !!tactic && (locked || status !== 'NotApplicable');
  const statusDescr = locked ? Locked : getStatusDescription(tactical);
  const onClose = (): void => setSelected(undefined);
  const onPlay = (): void => { if (isReady) applyTactic(tactic); };
  const onClear = (): void => {
    Server.send(TIP.clearNode, node);
    setSelected(undefined);
  };
  const parameters =
    (node && tactic)
    ? params.map((prm: TAC.parameter) =>
      <Parameter
        key={prm.id}
        node={node}
        tactic={tactic}
        locked={locked}
        {...prm}/>
    ) : null;
  return (
    <Hbox
      className="dome-xToolBar dome-color-frame wp-configure"
      display={display}
    >
      <Item
        key='tactic'
        icon='TUNINGS'
        title='Selected Tactic Configuration'
        className="wp-config-tactic"
        label={label} />
      <Descr
        key='info'
        icon='CIRC.INFO'
        className="wp-config-info"
        label={title} />
      <Filler key='filler'/>
      <Descr
        key='status'
        className="wp-config-info"
        title='Tactic Status'
        {...statusDescr} />
      <Fragment key='params'>{parameters}</Fragment>
      <IconButton
        key='play'
        icon={locked ? 'LOCK' : 'MEDIA.PLAY'}
        kind='positive'
        title='Apply Tactic'
        enabled={isReady}
        onClick={onPlay} />
      <IconButton
        key='close'
        icon='CIRC.CLOSE'
        title='Close Tactic Configuration Panel'
        display={!locked}
        onClick={onClose} />
      <IconButton
        key='clear'
        icon='CIRC.CLOSE'
        kind='negative'
        display={locked}
        title='Cancel Tactic and Remove Sub-Tree'
        onClick={onClear} />
    </Hbox>
  );
}

/* -------------------------------------------------------------------------- */
