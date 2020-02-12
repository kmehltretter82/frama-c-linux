// --------------------------------------------------------------------------
// --- Project Home View
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import Toolbar from 'dome/layout/toolbars' ;
import { Scroll, Hpack, Vbox, Vfill, Hfill } from 'dome/layout/boxes' ;
import { Splitter } from 'dome/layout/splitters' ;
import { Title, Label, Code, Descr } from 'dome/controls/labels' ;
import { Button, IconButton } from 'dome/controls/buttons' ;
import Ivette from '@ivette' ;
import Project from './Project' ;

// --------------------------------------------------------------------------
// --- Generic Dongle
// --------------------------------------------------------------------------

function Dongle({ id, label, title, selected, onSelect, children })
{
  const wident = id && <Code className='ivette-dongle-id' label={id}/> ;
  const wlabel = label && <Label label={label} /> ;
  const wdescr = title && <Descr label={title} /> ;
  const classes = 'ivette-dongle'
        + (onSelect ? ' ivette-dongle-selectable' : '')
        + (selected ? ' ivette-dongle-selected' : '') ;
  return (
    <Hfill className={classes}
           onClick={onSelect} >
      {wident}
      <Vfill>
        {wlabel}
        {wdescr}
      </Vfill>
      { children }
    </Hfill>
  );
}

// --------------------------------------------------------------------------
// --- Module Dongle
// --------------------------------------------------------------------------

function ModuleDongle({ module, current, configure })
{
  let selected = module === current ;
  let configuring = configure && configure.modified ;
  let configured = configuring && configure.value && configure.value.id === module.id ;
  let SELECT = () => Project.setState({ current: module });
  let DISPLAY = () => Project.setState({ current: module, frame:'display' });
  let CONFIGURE = () => {
    if (configured) Project.setConfigure();
    else if (!configuring) Project.setConfiguring(module);
  };
  return (
    <Dongle id={module.id}
            label={module.label}
            title={module.title}
            selected={selected}
            onSelect={SELECT} >
      <Toolbar.ButtonGroup>
        <Toolbar.Button
          icon='DISPLAY' title={'Display ' + module.id}
          onClick={DISPLAY} />
        <Toolbar.Button
          icon='SETTINGS' title={'Configure ' + module.id}
          disabled={configuring && !configured}
          onClick={CONFIGURE} />
      </Toolbar.ButtonGroup>
    </Dongle>
  );
}

// --------------------------------------------------------------------------
// --- Plugin Dongle
// --------------------------------------------------------------------------

function PluginDongle({ plugin, configure })
{
  const CREATE = () => Project.setConfiguring( Ivette.newModule(plugin) );
  return (
    <Dongle label={plugin.label} title={plugin.title} >
      <Button icon='CIRC.PLUS' label='New'
              title='Create a new Module from this plugin'
              kind='positive'
              style={{ width:80, height: 32 }}
              disabled={configure && configure.modified}
              onClick={CREATE} />
    </Dongle>
  );
}

// --------------------------------------------------------------------------
// --- Main View
// --------------------------------------------------------------------------

export default function Home()
{
  const [ { current,configure } , setState ] = Project.useState();
  const PROJECT = Ivette.getProjectDirectory();

  const MODULES= Ivette.getModules().map((module) => (
          <ModuleDongle
            key={'M' + module.id}
            module={module}
            current={current}
            configure={configure}
            />
        ));

  const PLUGINS= Ivette.getPlugins().map((plugin) => (
          <PluginDongle
            key={'P' + plugin.id}
            plugin={plugin}
            configure={configure}
            />
        ));

  return (
    <Scroll>
      <Vbox>
        {PROJECT ? <Title label='Project'/> : null}
        {PROJECT ? <div className='ivette-project'><Code>{PROJECT}</Code></div> : null}
        {MODULES.length ? <Title label='Modules'/> : null}
        {MODULES}
        {MODULES.length ? <div style={{height: 32}}/> : null}
        {PLUGINS.length ? <Title label='Plugins'/> : null}
        {PLUGINS}
      </Vbox>
    </Scroll>
  );
}

// --------------------------------------------------------------------------
