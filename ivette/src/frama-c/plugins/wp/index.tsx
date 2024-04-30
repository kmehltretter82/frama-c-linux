/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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
import { Meter } from 'dome/controls/displays';
import { Group, Inset } from 'dome/frame/toolbars';
import * as Ivette from 'ivette';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import * as ASTview from 'frama-c/kernel/ASTview';
import { GoalTable } from './goals';
import { TIPView } from './tip';
import * as TIP from './tip';
import * as WP from 'frama-c/plugins/wp/api';
import './style.css';

/* -------------------------------------------------------------------------- */
/* --- Context Menus                                                      --- */
/* -------------------------------------------------------------------------- */

function addStartProofMenus(
  menu: Dome.PopupMenuItem[],
  attr: Ast.markerAttributesData,
): void {
  const { marker, kind } = attr;
  switch (kind) {
    case 'LFUN':
    case 'DFUN':
      menu.push({
        label: `Prove function using WP`,
        onClick: () => Server.send(WP.startProofs, marker)
      });
      return;
    case 'STMT':
      menu.push({
        label: `Prove statement annotations using WP`,
        onClick: () => Server.send(WP.startProofs, marker)
      });
      return;
    case 'PROPERTY':
      menu.push({
        label: `Prove property using WP`,
        onClick: () => Server.send(WP.startProofs, marker)
      });
      return;
  }
}

ASTview.registerMarkerMenuExtender(addStartProofMenus);

function addGenerateRTEGuardsMenu(
  menu: Dome.PopupMenuItem[],
  attr: Ast.markerAttributesData,
): void {
  const { marker, kind } = attr;
  switch (kind) {
    case 'LFUN':
    case 'DFUN':
      menu.push({
        label: `Populate WP RTE guards`,
        onClick: () => Server.send(WP.generateRTEGuards, marker)
      });
      return;
  }
}

ASTview.registerMarkerMenuExtender(addGenerateRTEGuardsMenu);

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
          icon='MEDIA.PLAY'
          title={tip ? 'Back to Goals' : 'Interactive Proof Transformer'}
          enabled={!!current}
          selected={tip}
          onClick={() => setTip(!tip)} />
      </Ivette.TitleBar>
      <GoalTable
        display={!tip}
        failed={failed}
        scoped={scoped}
        scope={scope}
        current={current}
        setCurrent={setCurrent}
        setTIP={() => setTip(true)}
        setGoals={setGoals}
        setTotal={setTotal}
      />
      <TIPView
        display={tip}
        goal={current}
        onClose={() => setTip(false)}
      />
    </>
  );
}

Ivette.registerComponent({
  id: 'fc.wp.goals',
  label: 'WP Goals',
  title: 'WP Generated Verification Conditions',
  children: <WPGoals />,
});

/* -------------------------------------------------------------------------- */
/* --- WP Server Activity                                                 --- */
/* -------------------------------------------------------------------------- */

function ServerActivity(): JSX.Element {
  const { done, todo, active, procs, running } = TIP.useServerActivity();
  const total = done + todo;
  const progress = done + active;
  const objective = done + todo + procs;
  const title = `${done} / ${todo} (${active} running, ${procs} procs)`;
  return (
    <Group display={total > 0} title={title}>
      <Label>WP</Label>
      <Meter min={0} value={progress} max={objective} />
      <Inset />
      <IconButton
        icon="MEDIA.HALT" kind="negative" enabled={running}
        onClick={TIP.cancelProofTasks} />
      <Inset />
    </Group>
  );
}

Ivette.registerStatusbar({
  id: 'fc.wp.server',
  children: <ServerActivity />,
});

/* -------------------------------------------------------------------------- */
/* --- WP View                                                            --- */
/* -------------------------------------------------------------------------- */

Ivette.registerView({
  id: 'fc.wp.main',
  label: 'WP View',
  layout: {
    'A': 'fc.kernel.astview',
    'B': 'fc.kernel.astinfo',
    'CD': 'fc.wp.goals',
  }
});

// --------------------------------------------------------------------------
