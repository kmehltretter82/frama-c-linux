// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import { Catch } from 'dome/errors' ;
import { Vfill } from 'dome/layout/boxes' ;
import { Splitter } from 'dome/layout/splitters' ;
import Toolbar from 'dome/layout/toolbars' ;
import Sidebar from 'dome/layout/sidebars' ;

import './style.css' ;
import 'dome/misc/exports' ;

import { LabView, View, Group, Component } from 'frama-c/labviews' ;
import ServerControl from './ServerControl' ;

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default (function() {

  const [sidebar,flipSidebar] = Dome.useSwitch('frama-c.sidebar.unfold',false);
  const [viewbar,flipViewbar] = Dome.useSwitch('frama-c.viewbar.unfold',false);

  return (
    <Vfill>
      <Toolbar.ToolBar>
        <Toolbar.Button
          icon='SIDEBAR' title='Show/Hide side bar'
          selected={sidebar}
          onClick={flipSidebar}
          />
        <Toolbar.Filler/>
        <Toolbar.Button
          icon='ITEMS.GRID'
          title='Customize Main View'
          selected={viewbar}
          onClick={flipViewbar}/>
      </Toolbar.ToolBar>
      <Splitter dir='LEFT' settings='frame-c.sidebar.position' unfold={sidebar}>
        <Sidebar.SideBar>
          <div>(Empty)</div>
        </Sidebar.SideBar>
        <LabView
          customize={viewbar}
          settings='frama-c.labview'
          >
          <View id='default' label='Dashboard' defaultView />
          <Component id='dashboard' label='Dashboard'/>
          <Group id='plugins' label='Plugins'>
            <Component id='plugins.eva' label='Frama-C / EVA' />
            <Component id='plugins.wp'  label='Frama-C / WP' />
          </Group>
        </LabView>
      </Splitter>
      <Toolbar.ToolBar>
        <ServerControl/>
      </Toolbar.ToolBar>
    </Vfill>
  );

});

// --------------------------------------------------------------------------
