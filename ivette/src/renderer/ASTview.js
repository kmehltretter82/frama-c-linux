// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import Server from 'frama-c/server' ;
import States from 'frama-c/states' ;

import { Vfill } from 'dome/layout/boxes' ;
import { Buffer } from 'dome/text/buffers' ;
import { Text } from 'dome/text/editors' ;
import { Component } from 'frama-c/labviews' ;

import 'codemirror/mode/clike/clike.js';
import 'codemirror/theme/ambiance.css' ;

// --------------------------------------------------------------------------
// --- Rich Text Printer
// --------------------------------------------------------------------------

const print = async (buffer, text) => {
  if (Array.isArray(text)) {
    const tag = text.shift();
    if (tag !== '')
      buffer.openTextMarker( { id:tag } );
    for (const k in text)
      await print(buffer, text[k]);
    if (tag !== '')
      buffer.closeTextMarker();
  } else if (typeof(text)==='string')
    buffer.append(text);
};

// --------------------------------------------------------------------------
// --- AST Printer
// --------------------------------------------------------------------------

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo( () => new Buffer(), []);
  const [ select, setSelect ] = States.useSelection();
  const theFunction = select && select.function ;
  React.useEffect( () => {
    buffer.clear();
    if (theFunction) {
      buffer.log('Loading',theFunction,'…');
      Server
      .sendGET("kernel.ast.printFunction", theFunction)
      .then(data => {
        buffer.clear();
        return print(buffer,data);
      });
    }
  }, [ theFunction ] );

  return (
    <Vfill>
      <div>Function: {select && select.function}</div>
      <div>Marker: {select && select.marker}</div>
      <Text buffer={buffer}
            mode='text/x-csrc'
            theme='ambiance'
            readOnly />
    </Vfill>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component id='frama-c.astview'
             label='AST'
             title='Normalized source code representation.'
             >
    <ASTview/>
  </Component>
);

// --------------------------------------------------------------------------
