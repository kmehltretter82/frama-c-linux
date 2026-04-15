/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

// --- React & Dome

import React from 'react';
import { Hfill, Vfill } from 'dome/layout/boxes';
import { LSplit } from 'dome/layout/splitters';
import * as Toolbar from 'dome/frame/toolbars';
import { docChapters } from 'dome/help';
import { useGlobalState } from 'dome/data/states';
import * as Sidebar from './Sidebar';
import * as Controller from './Controller';
import { TOOLBAR, STATUSBAR, DOCCHAPTER } from 'ivette';
import * as State from 'ivette/state';
import * as Search from 'ivette/search';
import * as Laboratory from 'ivette/laboratory';
import * as IvettePrefs from 'ivette/prefs';
import { useSidebarControl } from './sidebarControl';
import './command';
import './loader';
import './sandbox';
import './style.css';

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default function Application(): JSX.Element {
  const sidebarPanel = useSidebarControl();

  const ToolBar = State.useChildren(TOOLBAR);
  const StatusBar = State.useChildren(STATUSBAR);

  const [, setChapters] = useGlobalState(docChapters);
  setChapters(DOCCHAPTER.getElements());

  return (
    <Vfill>
      <Toolbar.ToolBar>
        <Toolbar.Button
          icon="SIDEBAR"
          title={(sidebarPanel.visible ? "Collapse" : "Expand") + " sidebar"}
          selected={sidebarPanel.visible}
          onClick={() => sidebarPanel.setVisible(!sidebarPanel.visible)}
        />
        <Controller.Control />
        <>{ToolBar}</>
        <Toolbar.Filler />
        <Laboratory.Tabs />
        <Toolbar.Filler />
        <IvettePrefs.ThemeSwitchTool />
        <IvettePrefs.FontTools />
        <Search.SearchField />
        <Toolbar.IconPinnedMessage />
      </Toolbar.ToolBar>
      <Hfill>
        <Sidebar.Selectors
          panelVisible={sidebarPanel.visible}
          setPanelVisible={sidebarPanel.setVisible}
        />
        <LSplit
          position={sidebarPanel.position}
          onPosition={sidebarPanel.setPosition}
          allowResizeToZero
        >
          <Sidebar.Panels />
          <Laboratory.LabView />
        </LSplit>
      </Hfill>
      <Toolbar.ToolBar className="statusbar">
        <Controller.Status />
        <>{StatusBar}</>
        <Toolbar.Filler />
        <Laboratory.Dock />
      </Toolbar.ToolBar>
    </Vfill>
  );
}

// --------------------------------------------------------------------------
