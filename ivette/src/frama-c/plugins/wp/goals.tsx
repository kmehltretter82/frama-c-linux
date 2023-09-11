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
import { IconKind, Cell } from 'dome/controls/labels';
import { Filter } from 'dome/table/models';
import { Table, Column } from 'dome/table/views';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';

/* -------------------------------------------------------------------------- */
/* --- Status Column                                                      --- */
/* -------------------------------------------------------------------------- */

interface IconStatus {
  icon: string;
  kind: IconKind;
  title: string;
}

interface Status extends IconStatus { label: string }

const noResult : IconStatus =
  { icon: 'MINUS', kind: 'disabled', title: 'No Result' };

const baseStatus : { [key:string]: IconStatus } = {
  'VALID': { icon: 'CHECK', kind: 'positive', title: 'Valid Goal' },
  'PASSED': { icon: 'CHECK', kind: 'positive', title: 'Passed Test' },
  'DOOMED': { icon: 'CROSS', kind: 'negative', title: 'Doomed Test' },
  'FAILED': { icon: 'WARNING', kind: 'negative', title: 'Prover Failure' },
  'UNKNOWN': { icon: 'ATTENTION', kind: 'warning', title: 'Prover Stucked' },
  'TIMEOUT': { icon: 'HELP', kind: 'warning', title: 'Prover Timeout' },
  'STEPOUT': { icon: 'HELP', kind: 'warning', title: 'Prover Stepout' },
  'COMPUTING': { icon: 'EXECUTE', kind: 'default', title: 'Computing…' },
};

function getStatus(g : WP.goalsData): Status {
  const base = baseStatus[g.status] ?? noResult;
  return { ...base, label: g.stats.summary };
}

function renderStatus(s : Status): JSX.Element {
  return <Cell {...s} />;
}

/* -------------------------------------------------------------------------- */
/* --- Goals Filter                                                       --- */
/* -------------------------------------------------------------------------- */

function filterGoal(
  failed: boolean,
  scope: string | undefined,
): Filter<WP.goal, WP.goalsData> {
  return (goal: WP.goalsData): boolean => {
    if (failed && goal.passed) return false;
    if (scope && scope && goal.fct !== scope) return false;
    return true;
  };
}

/* -------------------------------------------------------------------------- */
/* --- Goals Table                                                        --- */
/* -------------------------------------------------------------------------- */

export interface GoalTableProps {
  scope: string | undefined;
  failed: boolean;
}

export function GoalTable(props: GoalTableProps): JSX.Element {
  const { scope, failed } = props;
  const model = States.useSyncArrayModel(WP.goals);
  const [_, updateAstSelection] = States.useSelection();
  const [wpoSelection, setWpoSelection] = React.useState(WP.goalDefault);

  const onWpoSelection = React.useCallback(
    ({ wpo, property: marker, fct }: WP.goalsData) => {
      const location = { fct, marker };
      updateAstSelection({ location });
      setWpoSelection(wpo);
    }, [updateAstSelection],
  );

  React.useEffect(() => {
    if (failed || !!scope) {
      model.setFilter(filterGoal(failed, scope));
    } else {
      model.setFilter();
    }
  }, [model, scope, failed]);

  return (
    <Table
      model={model}
      settings='wp.goals'
      onSelection={onWpoSelection}
      selection={wpoSelection}
    >
      <Column id='name' label='Property' width={200} />
      <Column id='status' label='Status' fill={true}
              getter={getStatus} render={renderStatus} />
    </Table>
  );
}

/* -------------------------------------------------------------------------- */
