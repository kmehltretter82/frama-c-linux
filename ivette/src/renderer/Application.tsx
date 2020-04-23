// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

import React from 'react';
import Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
import { Splitter } from 'dome/layout/splitters';
import Toolbar from 'dome/layout/toolbars';
import Sidebar from 'dome/layout/sidebars';

import './style.css';

import { LabView, View, Group } from 'frama-c/LabViews';
import { GridItem } from 'dome/layout/grids';
import Controller from './Controller';
import Properties from './Properties';
import ASTview from './ASTview';

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default (() => {
  const [sidebar, flipSidebar] = Dome.useSwitch(
    'frama-c.sidebar.unfold',
    false,
  );
  const [viewbar, flipViewbar] = Dome.useSwitch(
    'frama-c.viewbar.unfold',
    false,
  );

  return (
    <Vfill>
      <Toolbar.ToolBar>
        <Toolbar.Button
          icon="SIDEBAR"
          title="Show/Hide side bar"
          selected={sidebar}
          onClick={flipSidebar}
        />
        <Controller.Control />
        <Toolbar.Filler />
        <Toolbar.Button
          icon="ITEMS.GRID"
          title="Customize Main View"
          selected={viewbar}
          onClick={flipViewbar}
        />
      </Toolbar.ToolBar>
      <Splitter dir="LEFT" settings="frame-c.sidebar.position" unfold={sidebar}>
        <Sidebar.SideBar>
          <div>(Empty)</div>
        </Sidebar.SideBar>
        <LabView
          customize={viewbar}
          settings="frama-c.labview"
        >
          <View id="dashboard" label="Dashboard" defaultView>
            <GridItem id="frama-c.console" />
          </View>
          <Group id="frama-c" label="Frama-C" title="Frama-C Kernel Components">
            <Controller.Console />
            <Properties />
            <ASTview />
          </Group>
        </LabView>
      </Splitter>
      <Toolbar.ToolBar>
        <Controller.Status />
        <Toolbar.Filler />
        <Controller.Stats />
      </Toolbar.ToolBar>
    </Vfill>
  );
});

// --------------------------------------------------------------------------
