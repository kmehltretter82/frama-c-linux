// --------------------------------------------------------------------------
// --- Console
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import Server from 'frama-c/server' ;
import States from 'frama-c/states' ;

import { Filler, Button, ButtonGroup } from 'dome/layout/toolbars' ;
import { LED } from 'dome/controls/buttons' ;
import { Label, Code } from 'dome/controls/labels' ;
import { Text } from 'dome/text/editors' ;

import 'codemirror/theme/ambiance.css' ;

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

Dome.onCommand((argv,cwd) => {
  let params = [];
  let command ;
  let sockaddr ;
  for (let k = 0 ; k < argv.length ; k++) {
    let v = argv[k];
    switch(v) {
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
  Server.configure({ cwd, command, sockaddr, params });
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
  case 'IDLE':
    play = { enabled: true, onClick:Server.start };
    break;
  case 'RUNNING':
    stop = { enabled: true, onClick:Server.stop };
    reload = { enabled: true, onClick:Server.restart };
    break;
  }
  return (
    <ButtonGroup>
      <Button icon='MEDIA.PLAY' {...play}
              title='Start the server' />
      <Button icon='RELOAD' {...reload}
              title='Re-start the server' />
      <Button icon='MEDIA.STOP' {...stop}
              title='Shut down the server'/>
    </ButtonGroup>
  );
};

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

export const Console = () => {
  return (
    <Text buffer={Server.buffer}
          mode='text'
          theme="ambiance"
          readOnly="nocursor" />
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
  case Server.RUNNING:
    led = n>0 ? 'positive' : 'active' ;
    break;
  case Server.IDLE:
    led = 'inactive' ;
    break;
  case Server.STARTED:
    led = 'active' ;
    blink = true ;
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
