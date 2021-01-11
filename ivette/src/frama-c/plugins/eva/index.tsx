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
  label: 'Eva Values',
  title: 'Values inferred by the Eva analysis',
  children: <ValuesComponent />,
});

// --------------------------------------------------------------------------
