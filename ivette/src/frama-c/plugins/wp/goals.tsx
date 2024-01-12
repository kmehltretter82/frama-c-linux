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
import { IconKind, Cell, Descr } from 'dome/controls/labels';
import { Filter } from 'dome/table/models';
import { Table, Column } from 'dome/table/views';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import * as WP from 'frama-c/plugins/wp/api';

/* -------------------------------------------------------------------------- */
/* --- Scope Column                                                       --- */
/* -------------------------------------------------------------------------- */

function getScope(g : WP.goalsData): string {
  if (g.bhv && g.fct) return `${g.fct} — {g.bhv}}`;
  if (g.fct) return g.fct;
  if (g.thy) return g.thy;
  return '';
}

/* -------------------------------------------------------------------------- */
/* --- Status Column                                                      --- */
/* -------------------------------------------------------------------------- */

interface IconStatus {
  icon: string;
  label: string;
  kind: IconKind;
  title: string;
}

interface Status extends IconStatus { label: string }

const noResult : IconStatus =
  { icon: 'MINUS', label: 'No Result', kind: 'disabled', title: 'No Result' };

/* eslint-disable max-len */
const baseStatus : { [key:string]: IconStatus } = {
  'VALID': { icon: 'CHECK', label: 'Valid', kind: 'positive', title: 'Valid Goal' },
  'PASSED': { icon: 'CHECK', label: 'Passed', kind: 'positive', title: 'Passed Test' },
  'DOOMED': { icon: 'CROSS', label: 'Doomed', kind: 'negative', title: 'Doomed Test' },
  'FAILED': { icon: 'WARNING', label: 'Failed', kind: 'negative', title: 'Prover Failure' },
  'UNKNOWN': { icon: 'ATTENTION', label: 'Unknown', kind: 'warning', title: 'Prover Stucked' },
  'TIMEOUT': { icon: 'HELP', label: 'Timeout', kind: 'warning', title: 'Prover Timeout' },
  'STEPOUT': { icon: 'HELP', label: 'Stepout', kind: 'warning', title: 'Prover Stepout' },
  'COMPUTING': { icon: 'EXECUTE', label: 'Running', kind: 'default', title: 'Prover is running' },
};
/* eslint-enable max-len */

export function getStatus(g : WP.goalsData): Status {
  const { label, ...base } = baseStatus[g.status] ?? noResult;
  return { ...base, label: label + g.stats.summary };
}

function renderStatus(s : Status): JSX.Element {
  return <Cell {...s} />;
}

/* -------------------------------------------------------------------------- */
/* --- Goals Filter                                                       --- */
/* -------------------------------------------------------------------------- */

function filterGoal(
  failed: boolean,
  scope: Ast.decl | undefined,
): Filter<WP.goal, WP.goalsData> {
  return (goal: WP.goalsData): boolean => {
    if (failed && goal.passed) return false;
    if (scope && goal.scope !== scope) return false;
    return true;
  };
}

/* -------------------------------------------------------------------------- */
/* --- Goals Table                                                        --- */
/* -------------------------------------------------------------------------- */

export interface GoalTableProps {
  display: boolean;
  failed: boolean;
  scoped: boolean;
  scope: Ast.decl | undefined;
  current: WP.goal | undefined;
  setCurrent: (goal: WP.goal) => void;
  setTIP: (goal: WP.goal) => void;
  setGoals: (goals: number) => void;
  setTotal: (total: number) => void;
}

export function GoalTable(props: GoalTableProps): JSX.Element {
  const {
    display, scoped, failed,
    scope, current, setCurrent, setTIP,
    setGoals, setTotal,
  } = props;
  const { model } = States.useSyncArrayProxy(WP.goals);
  const goals = model.getRowCount();
  const total = model.getTotalRowCount();
  const onSelection = React.useCallback(
    ({ wpo, marker }: WP.goalsData) => {
      States.setSelected(marker);
      setCurrent(wpo);
    }, [setCurrent]);
  const onDoubleClick = React.useCallback(
    ({ wpo }: WP.goalsData) => {
      setTIP(wpo);
    }, [setTIP]
  );

  React.useEffect(() => {
    if (failed || !!scope) {
      model.setFilter(filterGoal(failed, scope));
    } else {
      model.setFilter();
    }
  }, [model, scope, failed]);

  React.useEffect(() => setGoals(goals), [goals, setGoals]);
  React.useEffect(() => setTotal(total), [total, setTotal]);

  const renderEmpty = React.useCallback(() => {
    const kind = failed ? ' failed' : '';
    const loc = scoped ? ' in current scope' : '';
    const icon = scoped ? 'CURSOR' : failed ? 'CIRC.INFO' : 'INFO';
    return (
      <Descr
        className='wp-empty-goals'
        icon={icon} label={`No${kind} goals${loc}`} />
    );
  }, [scoped, failed]);

  return (
    <Table
      model={model}
      display={display}
      settings='wp.goals'
      selection={current}
      onSelection={onSelection}
      onDoubleClick={onDoubleClick}
      renderEmpty={renderEmpty}
    >
      <Column id='scope' label='Scope'
              width={150}
              getter={getScope} />
      <Column id='name' label='Property'
              width={150} />
      <Column id='status' label='Status'
              fill={true}
              getter={getStatus} render={renderStatus} />
    </Table>
  );
}

/* -------------------------------------------------------------------------- */
