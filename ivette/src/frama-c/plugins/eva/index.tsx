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
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import * as Dome from 'dome';
import * as Ivette from 'ivette';
import { Vfill } from 'dome/layout/boxes';
import { IconButton } from 'dome/controls/buttons';
import { AutoSizer } from 'react-virtualized';

// Locals
import { ProbeInfos } from './probeinfos';
import { Dimension, ValuesPanel } from './valuetable';
import { AlarmsInfos, StackInfos } from './valueinfos';
import './style.css';

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

function ValuesComponent() {
  const [zoom, setZoom] = Dome.useNumberSettings('eva-zoom-factor', 0);
  return (
    <>
      <Ivette.TitleBar>
        <IconButton
          enabled={zoom > 0}
          icon="ZOOM.OUT"
          onClick={() => setZoom(zoom - 1)}
        />
        <IconButton
          enabled={zoom < 20}
          icon="ZOOM.IN"
          onClick={() => setZoom(zoom + 1)}
        />
      </Ivette.TitleBar>
      <Vfill>
        <ProbeInfos />
        <Vfill>
          <AutoSizer>
            {(dim: Dimension) => (
              <ValuesPanel
                zoom={zoom}
                {...dim}
              />
            )}
          </AutoSizer>
        </Vfill>
        <AlarmsInfos />
        <StackInfos />
      </Vfill>
    </>
  );
}

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

Ivette.registerComponent({
  id: 'frama-c.plugins.values',
  group: 'frama-c.plugins',
  rank: 1,
  label: 'Eva Values',
  title: 'Values inferred by the Eva analysis',
  children: <ValuesComponent />,
});

Ivette.registerView({
  id: 'values',
  rank: 1,
  label: 'Eva Values',
  layout: [
    ['frama-c.astview', 'frama-c.plugins.values'],
    'frama-c.properties',
  ],
});

// --------------------------------------------------------------------------
