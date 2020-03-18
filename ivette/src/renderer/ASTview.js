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
  const theMarker = select && select.marker ;

  // Hook: async loading
  React.useEffect( () => {
    buffer.clear();
    if (theFunction) {
      buffer.log('// Loading',theFunction,'…');
      Server
      .sendGET("kernel.ast.printFunction", theFunction)
      .then(data => {
        buffer.clear();
        if (!data)
          buffer.log('// No code for function ', theFunction);
        return print(buffer,data);
      });
    }
  }, [ theFunction ] );

  // Callbacks
  const onSelection = marker => setSelect({ marker });

  // Component
  return (
    <Vfill>
      <Text buffer={buffer}
            mode='text/x-csrc'
            theme='ambiance'
            selection={theMarker}
            onSelection={onSelection}
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
