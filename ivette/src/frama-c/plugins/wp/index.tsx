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
import { IconButton } from 'dome/controls/buttons';
import * as Ivette from 'ivette';
import * as States from 'frama-c/states';
import { GoalTable } from './goals';
import './style.css';

/* -------------------------------------------------------------------------- */
/* --- Goal Component                                                     --- */
/* -------------------------------------------------------------------------- */

function WPGoals(): JSX.Element {
  const [scoped, flipScoped] = Dome.useFlipSettings('frama-c.wp.goals.scoped');
  const [failed, flipFailed] = Dome.useFlipSettings('frama-c.wp.goals.failed');
  const [selection] = States.useSelection();
  const fct = selection?.current?.fct;
  const scope = scoped ? fct : undefined;
  return (
    <>
      <Ivette.TitleBar>
        <IconButton icon='COMPONENT' title='Current Scope Only'
                    enabled={!!fct}
                    selected={scoped} onClick={flipScoped} />
        <IconButton icon='CIRC.QUESTION' title='Unresolved Goals Only'
                    selected={failed} onClick={flipFailed} />
      </Ivette.TitleBar>
      <GoalTable scope={scope} failed={failed} />
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
/* --- WP View                                                            --- */
/* -------------------------------------------------------------------------- */

Ivette.registerView({
  id: 'wp.main',
  rank: 5,
  label: 'WP View',
  layout: [
    ['frama-c.astview', 'frama-c.astinfo'],
    'frama-c.plugins.wp.goals',
  ],
});

// --------------------------------------------------------------------------
