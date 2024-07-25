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
// --- Regions
// --------------------------------------------------------------------------

import React from 'react';
import { Label } from 'dome/controls/labels';
import { LCD } from 'dome/controls/displays';
import { IconButton } from 'dome/controls/buttons';
import * as Dome from 'dome';
import * as Tools from 'dome/frame/toolbars';
import * as Ivette from 'ivette';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Region from './api';
import { MemoryView } from './memory';
import './style.css';

function RegionAnalys(): JSX.Element {
  const [kf, setKf] = React.useState<States.Scope>();
  const [kfName, setName] = React.useState<string>();
  const [pinned, setPinned] = React.useState(false);
  const [running, setRunning] = React.useState(false);
  const setComputing = Dome.useProtected(setRunning);
  const { scope, marker } = States.useCurrentLocation();
  const { kind, name } = States.useDeclaration(scope);
  const regions = States.useRequestStable(Region.regions, kf);
  const node = States.useRequestStable(Region.localize, marker);
  const { descr: label } = States.useMarker(marker);
  React.useEffect(() => {
    if (!pinned && kind === 'FUNCTION' && scope !== kf) {
      setKf(scope);
      setName(name);
    } else if (!Server.isRunning()) {
      setKf(undefined);
      setName(undefined);
      setPinned(false);
    }
  }, [pinned, kind, name, scope, kf]);
  async function compute(): Promise<void> {
    try {
      setComputing(true);
      await Server.send(Region.compute, kf);
    } finally {
      setComputing(false);
    }
  }
  return (
    <>
      <Tools.ToolBar>
        <Label label='Function' />
        <LCD className='region-lcd' label={kfName ?? '---'} />
        <Tools.Button
          icon={running ? 'EXECUTE' : 'MEDIA.PLAY'}
          title='Run region analysis on the selected function'
          disabled={running}
          visible={kf !== undefined && regions.length === 0}
          onClick={compute}
        />
        <IconButton
          icon='PIN'
          display={kf !== undefined}
          title='Keep focus on current function'
          selected={pinned}
          onClick={() => setPinned(!pinned)}
        />
      </Tools.ToolBar>
      <MemoryView regions={regions} node={node} label={label} />
    </>
  );
}

Ivette.registerComponent({
  id: 'fc.region.main',
  label: 'Region Analysis',
  preferredPosition: 'BD',
  children: <RegionAnalys />,
});

// --------------------------------------------------------------------------
