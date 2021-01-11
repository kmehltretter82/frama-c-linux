// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

// --- React & Dome

import React from 'react';
import * as Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
import { LSplit } from 'dome/layout/splitters';
import * as Toolbar from 'dome/frame/toolbars';
import * as Sidebar from 'dome/frame/sidebars';
import { GridHbox, GridItem } from 'dome/layout/grids';

// --- Ivette

import { View, Group } from 'ivette';

// --- Frama-C

import History from 'frama-c/kernel/History';
import Globals from 'frama-c/kernel/Globals';
import ASTview from 'frama-c/kernel/ASTview';
import ASTinfo from 'frama-c/kernel/ASTinfo';
import Properties from 'frama-c/kernel/Properties';
import Locations from 'frama-c/kernel/Locations';
import SourceCode from 'frama-c/kernel/SourceCode';
import Values from 'frama-c/plugins/eva';
import Dive from 'frama-c/plugins/dive';

import * as Controller from './Controller';
import * as Extensions from './Extensions';
import { LabView } from './LabView';

import 'frama-c/kernel/style.css';

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default (() => {
  const [sidebar, flipSidebar] =
    Dome.useFlipSettings('frama-c.sidebar.unfold', true);
  const [viewbar, flipViewbar] =
    Dome.useFlipSettings('frama-c.viewbar.unfold', true);
  const hints = Extensions.useSearchHints();
  const onSelectedHints = () => {
    if (hints.length === 1) Extensions.onSearchHint(hints[0]);
  };

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
        <History />
        <Toolbar.Filler />
        <Toolbar.SearchField
          placeholder="Search…"
          hints={hints}
          onSearch={Extensions.searchHints}
          onHint={Extensions.onSearchHint}
          onSelect={onSelectedHints}
        />
        <Toolbar.Button
          icon="ITEMS.GRID"
          title="Customize Main View"
          selected={viewbar}
          onClick={flipViewbar}
        />
      </Toolbar.ToolBar>
      <LSplit settings="frama-c.sidebar.split" unfold={sidebar}>
        <Sidebar.SideBar>
          <div className="sidebar-ruler" />
          <Globals />
        </Sidebar.SideBar>
        <LabView
          customize={viewbar}
          settings="frama-c.labview"
        >
          <View id="console" label="Console" defaultView>
            <GridItem id="frama-c.console" />
          </View>
          <View id="values" label="Values">
            <GridHbox>
              <GridItem id="frama-c.astview" />
              <GridItem id="frama-c.values" />
            </GridHbox>
            <GridItem id="frama-c.properties" />
          </View>
          <View id="dive" label="Dive">
            <GridHbox>
              <GridItem id="frama-c.astview" />
              <GridItem id="dive.graph" />
              <GridItem id="frama-c.locations" />
            </GridHbox>
            <GridHbox>
              <GridItem id="frama-c.properties" />
              <GridItem id="frama-c.console" />
            </GridHbox>
          </View>
          <Group id="frama-c" label="Frama-C" title="Frama-C Kernel Components">
            <Controller.Console />
            <Properties />
            <SourceCode />
            <ASTview />
            <ASTinfo />
            <Locations />
            <Dive />
            <Values />
          </Group>
        </LabView>
      </LSplit>
      <Toolbar.ToolBar>
        <Controller.Status />
        <Toolbar.Filler />
        <Controller.Stats />
      </Toolbar.ToolBar>
    </Vfill>
  );
});

// --------------------------------------------------------------------------
