// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import { Vfill } from 'dome/layout/boxes';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component } from 'frama-c/LabViews';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';

// --------------------------------------------------------------------------
// --- Rich Text Printer
// --------------------------------------------------------------------------

const printAST = (buffer: any, text: string) => {
  if (Array.isArray(text)) {
    const tag = text.shift();
    if (tag !== '') {
      buffer.openTextMarker({ id: tag });
    }
    text.forEach((txt) => printAST(buffer, txt));
    if (tag !== '') {
      buffer.closeTextMarker();
    }
  } else if (typeof (text) === 'string') {
    buffer.append(text);
  }
};

async function loadAST(buffer: any, theFunction?: string, theMarker?: string) {
  buffer.clear();
  if (theFunction) {
    buffer.log('// Loading', theFunction, '…');
    (async () => {
      const data = await Server.GET({
        endpoint: 'kernel.ast.printFunction',
        params: theFunction,
      });
      const doc = buffer.getDoc();
      const cm = doc.getEditor();
      /* Buffer all the changes and only update the CodeMirror instance
         afterwards. This is crucial for performance. */
      cm.operation(() => {
        buffer.clear();
        if (!data)
          buffer.log('// No code for function ', theFunction);
        printAST(buffer, data);
        if (theMarker)
          buffer.scroll(theMarker, undefined);
      });
      return;
    })();
  }
}

// --------------------------------------------------------------------------
// --- AST Printer
// --------------------------------------------------------------------------

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const printed = React.useRef();
  const [select, setSelect] = States.useSelection();
  const theFunction = select && select.function;
  const theMarker = select && select.marker;

  // Hook: async loading
  React.useEffect(() => {
    if (printed.current !== theFunction) {
      printed.current = theFunction;
      loadAST(buffer, theFunction, theMarker);
    }
  });

  // Hook: marker scrolling
  React.useEffect(() => {
    if (theMarker) buffer.scroll(theMarker, undefined);
  }, [buffer, theMarker]);

  // Callbacks
  const onSelection = (marker: any) => setSelect({ marker });

  // Component
  return (
    <Vfill>
      <Text
        buffer={buffer}
        mode="text/x-csrc"
        theme="ambiance"
        selection={theMarker}
        onSelection={onSelection}
        readOnly
      />
    </Vfill>
  );

};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.astview"
    label="AST"
    title="Normalized source code representation."
  >
    <ASTview />
  </Component>
);

// --------------------------------------------------------------------------
