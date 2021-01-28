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
import * as Controller from './Controller';
import * as Extensions from './Extensions';
import * as Laboratory from './Laboratory';
import './loader';

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
        <Extensions.Toolbar />
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
          <Extensions.Sidebar />
        </Sidebar.SideBar>
        <Laboratory.LabView
          customize={viewbar}
          settings="frama-c.labview"
        />
      </LSplit>
      <Toolbar.ToolBar>
        <Controller.Status />
        <Extensions.Statusbar />
        <Toolbar.Filler />
        <Controller.Stats />
      </Toolbar.ToolBar>
    </Vfill>
  );
});

// --------------------------------------------------------------------------
