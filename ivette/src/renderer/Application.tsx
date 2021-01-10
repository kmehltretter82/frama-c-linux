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

import { LabView } from 'ivette@lab';
import { View, Group } from 'ivette';

// --- Frama-C

import * as States from 'frama-c/states';
import ASTview from 'frama-c/kernel/ASTview';
import ASTinfo from 'frama-c/kernel/ASTinfo';
import Properties from 'frama-c/kernel/Properties';
import Locations from 'frama-c/kernel/Locations';
import SourceCode from 'frama-c/kernel/SourceCode';
import Values from 'frama-c/plugins/eva';
import Dive from 'frama-c/plugins/dive';

import * as Controller from './Controller';
import Globals, { GlobalHint, useHints } from './Globals';

import 'frama-c/kernel/style.css';

// --------------------------------------------------------------------------
// --- Selection Controls
// --------------------------------------------------------------------------

const HistorySelectionControls = () => {
  const [selection, updateSelection] = States.useSelection();

  const doPrevSelect = () => { updateSelection('HISTORY_PREV'); };
  const doNextSelect = () => { updateSelection('HISTORY_NEXT'); };

  return (
    <Toolbar.ButtonGroup>
      <Toolbar.Button
        icon="ANGLE.LEFT"
        onClick={doPrevSelect}
        disabled={!selection || selection.history.prevSelections.length === 0}
        title="Previous location"
      />
      <Toolbar.Button
        icon="ANGLE.RIGHT"
        onClick={doNextSelect}
        disabled={!selection || selection.history.nextSelections.length === 0}
        title="Next location"
      />
    </Toolbar.ButtonGroup>
  );
};

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default (() => {
  const [sidebar, flipSidebar] =
    Dome.useFlipSettings('frama-c.sidebar.unfold', true);
  const [viewbar, flipViewbar] =
    Dome.useFlipSettings('frama-c.viewbar.unfold', true);
  const [hints, onSearchHint] = useHints();
  const [, setSelection] = States.useSelection();
  const onGlobalHint = (h: GlobalHint) => {
    setSelection({ location: h.value });
  };
  const onSelectHint = () => {
    if (hints.length === 1) onGlobalHint(hints[0]);
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
        <HistorySelectionControls />
        <Toolbar.Filler />
        <Toolbar.SearchField
          placeholder="Search…"
          hints={hints}
          onSearch={onSearchHint}
          onSelect={onSelectHint}
          onHint={onGlobalHint}
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
          <Globals key="globals" />
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
