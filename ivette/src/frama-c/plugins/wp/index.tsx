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

// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import { Label } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { LED, Meter } from 'dome/controls/displays';
import { Group, Inset } from 'dome/frame/toolbars';
import * as Ivette from 'ivette';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import { GoalTable } from './goals';
import { TIPView } from './tip';
import * as WP from 'frama-c/plugins/wp/api';
import './style.css';

/* -------------------------------------------------------------------------- */
/* --- Goal Component                                                     --- */
/* -------------------------------------------------------------------------- */

type Goal = WP.goal | undefined;

function WPGoals(): JSX.Element {
  const [scoped, flipScoped] = Dome.useFlipSettings('frama-c.wp.goals.scoped');
  const [failed, flipFailed] = Dome.useFlipSettings('frama-c.wp.goals.failed');
  const [tip, setTip] = React.useState(false);
  const [current, setCurrent] = React.useState<Goal>(undefined);
  Server.useShutdown(() => { setTip(false); setCurrent(undefined); });
  const scope = States.useCurrentScope();
  const [goals, setGoals] = React.useState(0);
  const [total, setTotal] = React.useState(0);
  const hasGoals = total > 0;
  return (
    <>
      <Ivette.TitleBar
        label={tip ? 'WP — TIP' : 'WP — Goals'}
        title={tip ? 'Interactive Proof Transformer' : 'Generated Goals'}
      >
        <Label display={goals < total}>
          {goals} / {total}
        </Label>
        <Inset />
        <IconButton
          icon='CURSOR' title='Current Scope Only'
          enabled={hasGoals}
          selected={scoped}
          onClick={flipScoped} />
        <IconButton
          icon='CIRC.QUESTION' title='Unresolved Goals Only'
          enabled={hasGoals}
          selected={failed}
          onClick={flipFailed} />
        <IconButton
          icon={tip ? 'ITEMS.LIST' : 'MEDIA.PLAY'}
          kind={tip ? 'warning' : 'positive'}
          title={tip ? 'Back to Goals' : 'Interactive Proof Transformer'}
          enabled={!!current}
          onClick={() => setTip(!tip)} />
      </Ivette.TitleBar>
      <GoalTable
        display={!tip}
        scope={scope}
        failed={failed}
        current={current}
        setCurrent={setCurrent}
        setTIP={() => setTip(true)}
        setGoals={setGoals}
        setTotal={setTotal}
      />
      <TIPView
        display={tip}
        goal={current} />
    </>
  );
}

Ivette.registerComponent({
  id: 'frama-c.plugins.wp.goals',
  group: 'frama-c.plugins',
  rank: 10,
  label: 'WP Goals',
  title: 'WP Generated Verification Conditions',
  children: <WPGoals />,
});

/* -------------------------------------------------------------------------- */
/* --- WP Server Activity                                                 --- */
/* -------------------------------------------------------------------------- */

function ServerActivity(): JSX.Element {
  const rq = States.useRequest(WP.getScheduledTasks, null);
  const active = rq ? rq.active > 0 : false;
  const status = active ? 'active' : 'inactive';
  const done = rq ? rq.done : 0;
  const todo = rq ? rq.todo : 0;
  const total = done + todo;
  return (
    <Group display={total > 0}>
      <LED status={status} />
      <Label>WP</Label>
      <Meter value={done} min={0} max={done + total} />
      <Inset />
    </Group>
  );
}

Ivette.registerStatusbar({
  id: 'frama-c.plugins.wp.server',
  children: <ServerActivity />,
});

/* -------------------------------------------------------------------------- */
/* --- WP View                                                            --- */
/* -------------------------------------------------------------------------- */

Ivette.registerView({
  id: 'frama-c.plugins.wp.main',
  rank: 5,
  label: 'WP View',
  layout: [
    ['frama-c.astview', 'frama-c.astinfo'],
    'frama-c.plugins.wp.goals',
  ],
});

// --------------------------------------------------------------------------
