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
import * as Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
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
import './command';
import './loader';
import './sandbox';
import './style.css';

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default function Application(): JSX.Element {
  const [sidebar, flipSidebar] =
    Dome.useFlipSettings('frama-c.sidebar.unfold', true);

  const ToolBar = State.useChildren(TOOLBAR);
  const StatusBar = State.useChildren(STATUSBAR);

  const [ , setChapters ] = useGlobalState(docChapters);
  setChapters(DOCCHAPTER.getElements());

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
        <>{ToolBar}</>
        <Toolbar.Filler />
        <Laboratory.Tabs />
        <Toolbar.Filler />
        <Toolbar.IconWarning />
        <IvettePrefs.ThemeSwitchTool />
        <IvettePrefs.FontTools />
        <Search.SearchField />
      </Toolbar.ToolBar>
      <LSplit settings="frama-c.sidebar.split" unfold={sidebar}>
        <Sidebar.Panel />
        <Laboratory.LabView />
      </LSplit>
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
