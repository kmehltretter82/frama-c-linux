// --------------------------------------------------------------------------
// --- Console
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import Server from 'frama-c/server' ;

import { Filler, Button } from 'dome/layout/toolbars' ;
import { LED } from 'dome/controls/buttons' ;
import { Label, Code } from 'dome/controls/labels' ;

Dome.onCommand(() => {
  Server.configure();
  Server.start();
  console.log('STARTED');
});

export default (function(props) {
  Dome.useUpdate( Server.SERVER );
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
      <Filler/>
      { error ? <Label icon='WARNING' label={error} /> : <Code>{n} rq.</Code> }
    </React.Fragment>
  );
});
