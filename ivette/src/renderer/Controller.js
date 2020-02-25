// --------------------------------------------------------------------------
// --- Server Controller
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import Server from 'frama-c/server' ;
import States from 'frama-c/states' ;

import { Vfill } from 'dome/layout/boxes' ;
import { Title } from 'frama-c/labviews' ;
import { Button as ToolButton, ButtonGroup, Filler  } from 'dome/layout/toolbars' ;
import { LED, IconButton } from 'dome/controls/buttons' ;
import { Label, Code } from 'dome/controls/labels' ;
import { Buffer } from 'dome/text/buffers' ;
import { Text } from 'dome/text/editors' ;

import 'codemirror/theme/ambiance.css' ;

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

var cmdConfig ;
const cmdLine = new Buffer();

function dumpCmdLine({ cwd, command, sockaddr, params })
{
  cmdLine.clear();
  if (cwd) cmdLine.log('--cwd',cwd);
  if (command) cmdLine.log('--command',command);
  if (sockaddr) cmdLine.log('--socket',sockaddr);
  params.forEach((v,i) => {
    if (i>0) {
      if (v.startsWith('-') || v.endsWith('.c') || v.endsWith('.h') || v.endsWith('.i'))
        cmdLine.append('\n');
      else
        cmdLine.append(' ');
    }
    cmdLine.append(v);
  });
  cmdLine.append('\n');
};

function configOfParams(argv,cwd) {
  let params = [];
  let command ;
  let sockaddr ;
  let working = cwd ;
  for (let k = 0 ; k < argv.length ; k++) {
    let v = argv[k];
    switch(v) {
    case '--cwd':
      working = argv[++k];
      break;
    case '--command':
      command = argv[++k];
      break;
    case '--socket':
      sockaddr = argv[++k];
      break;
    default:
      params.push(v);
    }
  }
  return { cwd:working, command, sockaddr, params };
}

Dome.onCommand((argv,cwd) => {
  cmdConfig = configOfParams(argv,cwd);
  dumpCmdLine(cmdConfig);
  Server.configure(cmdConfig);
  Server.start();
});

// --------------------------------------------------------------------------
// --- Server Control
// --------------------------------------------------------------------------

export const Control = () => {
  let status = Server.useStatus();
  let play = { enabled: false } ;
  let stop = { enabled: false } ;
  let reload = { enabled: false } ;
  switch(status) {
  case 'OFF':
  case 'FAILED':
    play = { enabled: true, onClick:Server.start };
    break;
  case 'RUNNING':
    stop = { enabled: true, onClick:Server.stop };
    reload = { enabled: true, onClick:Server.restart };
    break;
  }
  return (
    <ButtonGroup>
      <ToolButton icon='MEDIA.PLAY' {...play}
              title='Start the server' />
      <ToolButton icon='RELOAD' {...reload}
              title='Re-start the server' />
      <ToolButton icon='MEDIA.STOP' {...stop}
              title='Shut down the server'/>
    </ButtonGroup>
  );
};

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

function resetCmdLine() {
  dumpCmdLine( cmdConfig );
}

function execCmdLine() {
  let cmd = cmdLine.getDoc().getValue();
  let argv = cmd.trim().split(/[ \t\n]+/);
  let cfg = configOfParams(argv);
  Server.configure(cfg);
  Server.restart();
}

export const Console = () => {
  const [ cmd , switchCmd ] = Dome.useSwitch();
  const doExec = () => {
    switchCmd();
    execCmdLine();
  };
  return (
    <Vfill>
      <Title>
        <IconButton icon='RELOAD' display={cmd} onClick={resetCmdLine} title='Reset Command Line'/>
        <IconButton icon='MEDIA.PLAY' display={cmd} onClick={doExec} title='Execute Command Line'/>
        <IconButton icon='EDIT' selected={cmd} onClick={switchCmd} title='Edit Command Line'/>
      </Title>
      <Text buffer={cmd ? cmdLine : Server.buffer}
            mode='text'
            readOnly={!cmd}
            theme='ambiance' />
    </Vfill>
  );
};

// --------------------------------------------------------------------------
// --- Status
// --------------------------------------------------------------------------

export const Status = () => {
  Dome.useUpdate( Server.STATUS );
  let s = Server.getStatus();
  let n = Server.getPending();
  let led, blink, error ;
  switch(s) {
  case Server.OFF:
    led = 'inactive' ;
    break;
  case Server.STARTED:
    led = 'active' ;
    blink = true ;
    break;
  case Server.RUNNING:
    led = n>0 ? 'positive' : 'active' ;
    break;
  case Server.KILLING:
    led = 'negative' ;
    blink = true ;
    break;
  case Server.RESTART:
    led = 'warning' ;
    blink = true ;
    break;
  case Server.FAILED:
    led = 'negative' ;
    blink = false ;
    error = Server.getError();
    break;
  }
  return (
    <React.Fragment>
      <LED status={led} blink={blink} />
      <Code label={s}/>
      { error && <Label icon='WARNING' label={error} /> }
    </React.Fragment>
  );
};

// --------------------------------------------------------------------------
// --- Server Stats
// --------------------------------------------------------------------------

export const Stats = () => {
  Dome.useUpdate( Server.STATUS );
  let n = Server.getPending();
  return n > 0 ? <Code>{n} rq.</Code> : null ;
};

// --------------------------------------------------------------------------
// --- Controller Exports
// --------------------------------------------------------------------------

export default { Control, Console, Status, Stats };

// --------------------------------------------------------------------------
