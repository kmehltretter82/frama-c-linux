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
import { Cell } from 'dome/controls/labels';
import { Vfill, Hbox } from 'dome/layout/boxes';
import * as States from 'frama-c/states';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import { getStatus } from './goals';

/* -------------------------------------------------------------------------- */
/* --- TIP View                                                           --- */
/* -------------------------------------------------------------------------- */

export interface TIPProps {
  display: boolean;
  goal: WP.goal;
}

function useTarget(target: WP.goal | undefined) : WP.goalsData {
  const data = States.useSyncArrayElt( WP.goals, target );
  return data ?? WP.goalsDataDefault;
}

export function TIPView(props: TIPProps): JSX.Element {
  const { display, goal } = props;
  const target = goal !== WP.goalDefault ? goal : undefined;
  const infos: WP.goalsData = useTarget(goal);
  const status = getStatus(infos);
  const { index=0, pending=0 } =
    States.useRequest( TIP.getProofState, target ) ?? {};
  return (
    <Vfill display={display}>
      <Hbox>
        <Cell
          icon='HOME'
          label={infos.wpo} title='Goal identifier' />
        <Cell
          icon='CODE'
          display={pending > 0}
          label={`${index+1}/${pending}`} title='Pending proof nodes'/>
        <Cell {...status}/>
      </Hbox>
    </Vfill>
  );
}

/* -------------------------------------------------------------------------- */
