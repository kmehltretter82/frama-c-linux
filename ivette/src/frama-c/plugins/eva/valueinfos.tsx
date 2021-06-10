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
// --- Info Components
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import { classes } from 'dome/misc/utils';
import { Hpack, Vpack } from 'dome/layout/boxes';
import { Code, Cell } from 'dome/controls/labels';
import * as States from 'frama-c/states';

// Locals
import { EvaAlarm } from './cells';
import { Callsite } from './stacks';
import { useModel } from './model';

// --------------------------------------------------------------------------
// --- Stmt Printer
// --------------------------------------------------------------------------

interface StmtProps {
  stmt?: string;
  rank?: number;
}

export function Stmt(props: StmtProps) {
  const { rank, stmt } = props;
  if (rank === undefined || !stmt) return null;
  const title = `Stmt at global rank ${rank} (internal id: ${stmt})`;
  return (
    <span className="dome-text-cell eva-stmt" title={title}>
      @S{rank}
    </span>
  );
}

// --------------------------------------------------------------------------
// --- Alarms Panel
// --------------------------------------------------------------------------

export function AlarmsInfos() {
  const model = useModel();
  const probe = model.getFocused();
  if (probe) {
    const callstack = model.getCallstack();
    const domain = model.values.getValues(probe, callstack);
    const alarms = domain?.alarms ?? [];
    if (alarms.length > 0) {
      const renderAlarm = ([status, alarm]: EvaAlarm) => {
        const className = `eva-alarm-info eva-alarm-${status}`;
        return (
          <Code className={className} icon="WARNING">{alarm}</Code>
        );
      };
      return (
        <Vpack className="eva-info">
          {React.Children.toArray(alarms.map(renderAlarm))}
        </Vpack>
      );
    }
  }
  return null;
}

// --------------------------------------------------------------------------
// --- Stack Panel
// --------------------------------------------------------------------------

export function StackInfos() {
  const model = useModel();
  const [, setSelection] = States.useSelection();
  const focused = model.getFocused();
  const callstack = model.getCalls();
  if (callstack.length <= 1) return null;
  const makeCallsite = ({ caller, stmt, rank }: Callsite) => {
    if (!caller || !stmt) return null;
    const key = `${caller}@${stmt}`;
    const isFocused = focused?.marker === stmt;
    const isTransient = focused?.transient;
    const className = classes(
      'eva-callsite',
      isFocused && 'eva-focused',
      isTransient && 'eva-transient',
    );
    const select = (meta: boolean) => {
      const location = { fct: caller, marker: stmt };
      setSelection({ location });
      if (meta) States.MetaSelection.emit(location);
    };
    const onClick = (evt: React.MouseEvent) => {
      select(evt.altKey);
    };
    const onDoubleClick = (evt: React.MouseEvent) => {
      evt.preventDefault();
      select(true);
    };
    return (
      <Cell
        key={key}
        icon="TRIANGLE.LEFT"
        className={className}
        onClick={onClick}
        onDoubleClick={onDoubleClick}
      >
        {caller}
        <Stmt stmt={stmt} rank={rank} />
      </Cell>
    );
  };
  return (
    <Hpack className="eva-info">
      {callstack.map(makeCallsite)}
    </Hpack>
  );
}

// --------------------------------------------------------------------------
