/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

// --- React & Dome

import React from 'react';
import * as Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
import { LSplit } from 'dome/layout/splitters';
import * as Toolbar from 'dome/frame/toolbars';
import * as Sidebar from './Sidebar';
import * as Controller from './Controller';
import { TOOLBAR, STATUSBAR } from 'ivette';
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
