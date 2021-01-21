// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import * as Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
import { IconButton } from 'dome/controls/buttons';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';

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
      <TitleBar>
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
      </TitleBar>
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

export default () => (
  <Component
    id="frama-c.values"
    label="Eva Values"
    title="Values inferred by the Eva analysis"
  >
    <ValuesComponent />
  </Component>
);

// --------------------------------------------------------------------------
