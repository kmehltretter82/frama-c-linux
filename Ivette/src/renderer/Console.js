// --------------------------------------------------------------------------
// --- Console
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import { Buffer } from 'dome/text/buffers' ;
import { Text } from 'dome/text/editors' ;
import 'codemirror/theme/ambiance.css' ;

const buffer = new Buffer( { maxlines: 1024 } );

{
  Dome.on('refresh',() => buffer.setFocused(false));
  Dome.on('console',(msg) => { buffer.append(msg); buffer.scroll(); } );
  buffer.log('Welcome to Ivette !');
}

function Console(props) {
  return (
    <Text buffer={buffer}
          mode='text'
          theme="ambiance"
          readOnly="nocursor" />
  );
}

Console.log = (...args) => buffer.log(...args);
Console.clear = () => buffer.clear();

export default Console ;
