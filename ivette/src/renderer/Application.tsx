// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import * as States from 'frama-c/states';
import { Vfill } from 'dome/layout/boxes';
import { Splitter } from 'dome/layout/splitters';
import * as Toolbar from 'dome/frame/toolbars';
import * as Sidebar from 'dome/frame/sidebars';

import './style.css';

import { LabView, View, Group } from 'frama-c/LabViews';
import { GridItem } from 'dome/layout/grids';
import * as Controller from './Controller';

import ASTview from './ASTview';
import ASTinfo from './ASTinfo';
import Globals from './Globals';
import Properties from './Properties';
import DiveGraph from './dive_main.js';

// --------------------------------------------------------------------------
// --- Selection Controls
// --------------------------------------------------------------------------

const SelectionControls = () => {
  const [selection, updateSelection] = States.useSelection();

  const doPrevSelect = () => { updateSelection('GO_BACK'); };
  const doNextSelect = () => { updateSelection('GO_FORWARD'); };

  return (
    <Toolbar.ButtonGroup>
      <Toolbar.Button
        icon="MEDIA.PREV"
        onClick={doPrevSelect}
        disabled={!selection || selection.prevSelections.length === 0}
        title="Previous location"
      />
      <Toolbar.Button
        icon="MEDIA.NEXT"
        onClick={doNextSelect}
        disabled={!selection || selection.nextSelections.length === 0}
        title="Next location"
      />
    </Toolbar.ButtonGroup>
  );
};

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
        <SelectionControls />
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
          <div className="sidebar-ruler" />
          <Globals key="globals" />
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
            <ASTinfo />
            <DiveGraph />
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
