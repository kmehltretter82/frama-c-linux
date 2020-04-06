// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import _ from 'lodash';
import React from 'react';
import Server from 'frama-c/server';
import States from 'frama-c/states';

import { Vfill } from 'dome/layout/boxes';
import { Buffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component } from 'frama-c/LabViews';

import 'codemirror/mode/clike/clike.js';
import 'codemirror/theme/ambiance.css';

// --------------------------------------------------------------------------
// --- Rich Text Printer
// --------------------------------------------------------------------------

const print = (buffer: any, text: string) => {
  if (Array.isArray(text)) {
    const tag = text.shift();
    if (tag !== '')
      buffer.openTextMarker({ id: tag });
    text.forEach(txt => print(buffer, txt));
    if (tag !== '')
      buffer.closeTextMarker();
  } else if (typeof (text) === 'string')
    buffer.append(text);
};

// --------------------------------------------------------------------------
// --- AST Printer
// --------------------------------------------------------------------------

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo(() => new Buffer(), []);
  const [select, setSelect] = States.useSelection();
  const theFunction = select && select.function;
  const theMarker = select && select.marker;

  // Hook: async loading
  React.useEffect(() => {
    buffer.clear();
    if (theFunction) {
      buffer.log('// Loading', theFunction, '…');
      Server
        .sendGET("kernel.ast.printFunction", theFunction)
        .then((data: string) => {
          buffer.clear();
          if (!data)
            buffer.log('// No code for function ', theFunction);
          print(buffer, data);
          if (theMarker) buffer.scroll(theMarker, undefined);
        });
    }
  }, [theFunction]);

  // Hook: scrolling
  React.useEffect(() => {
    if (theMarker) buffer.scroll(theMarker, undefined);
  }, [theMarker]);

  // Callbacks
  const onSelection = (marker: any) => setSelect({ marker });

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
    <ASTview />
  </Component>
);

// --------------------------------------------------------------------------
