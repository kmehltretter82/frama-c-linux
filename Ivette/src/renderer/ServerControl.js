// --------------------------------------------------------------------------
// --- Console
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import Server from 'frama-c/server' ;

import { Filler, Button } from 'dome/layout/toolbars' ;
import { LED } from 'dome/controls/buttons' ;
import { Label, Code } from 'dome/controls/labels' ;

export default (function(props) {
  Dome.useUpdate( Server.SERVER );
  let status = Server.getStatus();
  let led, blink, error ;
  switch(status) {
  case Server.RUNNING:
    led = Server.isPending() ? 'positive' : 'active' ;
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
  }
  return (
    <React.Fragment>
      <LED status={status} blink={blink} />
      { error && <Label icon='WARNING' label={error}/> }
      <Filler/>
      <Code>{Server.getPending()} rq.</Code>
    </React.Fragment>
  );
});
