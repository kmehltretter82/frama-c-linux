// --------------------------------------------------------------------------
// --- Frama-C Ivette Plug-in
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import Toolbar from 'dome/layout/toolbars' ;
import { GridItem, GridHbox, GridVbox } from 'dome/layout/grids' ;
import { Code } from 'dome/controls/labels' ;
import Ivette from '@ivette' ;
import { Module } from '@ivette/plugins' ;
import { PluginToolbar } from '@ivette/views' ;
import { LabView, View, Group, Component } from '@ivette/labviews' ;
import { Buffer } from 'dome/text/buffers' ;
import { ArrayModel } from 'dome/table/arrays' ;
import Dialogs from 'dome/dialogs';
import Server from './server';
import SourceFiles from './SourceFiles';
import Events from './Events';
import SourceCode from './SourceCode';
import Properties from './Properties';
import Project from "./Project";

// --------------------------------------------------------------------------
// --- Frama-C Plugin
// --------------------------------------------------------------------------

/* Load a Frama-C session. */
function LoadSession () {
  Dialogs.showOpenFile({message: 'Select a Frama-C save file'}).then
  ( path => {
    if (path) {
      console.log("Load session, path selected: " + path);
      Server.sendSET("kernel.load",path,false).then
      ( err => {
        if (err) {
          let message =
              { kind: 'error',
                title: 'Error while loading the Frama-C session',
                message: err,
                buttons: [{ label: 'Ok' }]
              };
          Dialogs.showMessageBox(message);
        } else {
          Dome.emit(Events.reload);
          console.log("Project successfully loaded.");
        }
      });
    } else
      console.log("Load session: no path selected.");
  });
}

function emitReload () {
  Dome.emit(Events.reload);
}

export class FramaC extends Module {

  constructor()
  {
    super();
    this.sourceCode = new Buffer ({ mode:'text/x-csrc' });
    this.functions = new ArrayModel ();
    this.getFunctions = this.getFunctions.bind(this);
    this.properties = new ArrayModel ();
    this.getProperties = this.getProperties.bind(this);
    Server.startServer();
    Dome.addMenuItem({
      menu: 'File',
      id: 'ivette.menu.file.load',
      label: 'Load session',
      key: 'Cmd+L',
      onClick: LoadSession
    });
  }

  /* Get the list of functions from the server, and fill [this.functions]. */
  getFunctions () {
    Server.sendGET("kernel.ast.getFunctions", [], false).then
    ( data => {
      console.log("Collecting " + data.length + " functions.");
      this.functions.clear();
      const array = new Array(data.length);
      data.forEach( (fct, index) => { array[index] = {fct: fct}; } );
      this.functions.setData(array);
    });
  }

  /* Get the list of properties from the server, and fill [this.properties]. */
  getProperties () {
    Server.sendGET("kernel.ast.getProperties", [], false).then
    ( data => {
      this.properties.clear();
      const array = new Array(data.length);
      data.forEach( (item, index) => {
        array[index] = { property: item.property,
                         fct: item.function,
                         status: item.status,
                         file: item.file };
      });
      this.properties.setData(array);
    });
  }

  renderMain() {
    let [ custom, setCustom ] = Dome.useState('sandbox.custom',false);
    Dome.useEvent(Events.reload, this.getFunctions);
    Dome.useEvent(Events.reload, this.getProperties);
    return (
      <React.Fragment>
        <PluginToolbar>
          <Toolbar.Button
            icon='FILE'
            label='Load'
            title='Load a Frama-C session'
            onClick={LoadSession}
          />
          <Toolbar.Filler/>
          <Toolbar.Button
            icon='RELOAD'
            title='Reload the tables'
            onClick={emitReload}
          />
          <Toolbar.Button
            icon='ITEMS.GRID'
            title='Customize Main View'
            selected={custom}
            onClick={() => setCustom(!custom)}/>
        </PluginToolbar>
        <LabView
          customize={custom}
          settings='sandbox.labview'
          >
          <View id='lab.main' label='Lab View' defaultView >
            <GridItem id='kernel.props' />
          </View>
          <View id='lab.eva' label='EVA Lab'>
            <GridHbox>
              <GridItem id='kernel.globals' />
              <GridItem id='plugins.eva' />
            </GridHbox>
          </View>
          <View id='lab.wp' label='WP Lab'>
            <GridHbox>
              <GridItem id='kernel.globals' />
              <GridItem id='plugins.wp' />
            </GridHbox>
          </View>
          <Component id='dashboard' label='Dashboard'/>
          <Group id='kernel' label='Kernel'>
            <Component id='kernel.project' label='Projects' >
              <Project />
            </Component>
            <Component id='kernel.source'   label='Source Code' >
              <SourceCode functions={this.functions}
                          sourceCode={this.sourceCode} />
            </Component>
            <Component id='kernel.files'   label='Source Files'>
              <SourceFiles />
              <Dome.Render>
                {() => {
                  let m = Ivette.useModule();
                  return (<Code> Module: {m.id} </Code>);
                }}
              </Dome.Render>
            </Component>
            <Component id='kernel.globals' label='Globals Index' />
            <Component id='kernel.ast'     label='AST Inspector' />
            <Component id='kernel.props'   label='Properties Status' >
              <Properties properties={this.properties} />
            </Component>
          </Group>
          <Group id='plugins' label='Plugins'>
            <Component id='plugins.eva' label='Frama-C / EVA' />
            <Component id='plugins.wp'  label='Frama-C / WP' />
            </Group>
            </LabView>
            </React.Fragment>
        );
  }

}

FramaC.id = 'frama-c-sandbox';
FramaC.label = "Frama-C Sandbox" ;
FramaC.title = "A playground for Frama-C" ;

// --------------------------------------------------------------------------
// --- Registration
// --------------------------------------------------------------------------

Ivette.registerPlugin( FramaC );

// --------------------------------------------------------------------------
