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
import { Table, Column } from 'dome/table/views';
import * as Ivette from 'ivette';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';

function WPGoals(): JSX.Element {
  const model = States.useSyncArrayModel(WP.goals);
  return (
    <Table model={model} settings='wp.goals'>
      <Column id='name' label='Names' />
    </Table>
  );
}


Ivette.registerComponent({
  id: 'frama-c.plugins.wp.vcs',
  group: 'frama-c.plugins',
  rank: 10,
  label: 'WP Goals',
  title: 'WP Generated Verification Conditions',
  children: <WPGoals />,
});
