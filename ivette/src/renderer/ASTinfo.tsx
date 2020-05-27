// --------------------------------------------------------------------------
// --- AST Information
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import { Vfill } from 'dome/layout/boxes';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component } from 'frama-c/LabViews';

// --------------------------------------------------------------------------
// --- Parsing information from the server
// --------------------------------------------------------------------------

function addMarker(buffer: RichTextBuffer, fct: string) {
  buffer.openTextMarker({ id: fct, css: 'color: blue' });
  buffer.append(fct);
  buffer.closeTextMarker();
}

function parseVarinfo(buffer: RichTextBuffer, data: any) {
  buffer.append(`Variable ${data.name} has type '${data.type.name}'.`);
  buffer.flushline();
  if (data.global) {
    buffer.append('It is a global variable.');
  } else {
    const kind = data.formal ? 'formal' : 'local';
    buffer.append(`It is a ${kind} variable of function `);
    addMarker(buffer, data.defining_function);
  }
  buffer.flushline();
  if (data.temp) {
    const descr = data.descr ? ` for ${data.descr}` : '';
    buffer.append(`This is a temporary variable${descr}.`);
    buffer.flushline();
  }
  const ref = data.referenced ? '' : 'not ';
  const taken = data.addrof ? '' : 'not ';
  buffer.append(`It is ${ref}referenced and its address is ${taken}taken.`);
}

function parseInfo(buffer: RichTextBuffer, data: any) {
  switch (data.kind) {
    case 'expression':
      buffer.append(`This is a pure C expression of type '${data.type.name}'.`);
      break;
    case 'function':
      addMarker(buffer, data.varinfo.name);
      buffer.append(` is a C function of type '${data.type.name}'.`);
      break;
    case 'variable':
      parseVarinfo(buffer, data.varinfo);
      break;
    case 'lvalue':
      buffer.append(`This is an lvalue of type '${data.type.name}'.`);
      break;
    case 'declaration':
      buffer.append('This is the declaration of variable '
        + `${data.varinfo.name}.`);
      buffer.flushline(); buffer.append(' '); buffer.flushline();
      parseVarinfo(buffer, data.varinfo);
      break;
    case 'statement':
      buffer.append(`This is a statement of function ${data.function}.`);
      break;
    default:
      break;
  }
}

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

const ASTinfo = () => {

  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [select, setSelect] = States.useSelection();
  const marker = select && select.marker;
  const data = States.useRequest('kernel.ast.info', marker);

  React.useEffect(() => {
    buffer.clear();
    if (data) {
      parseInfo(buffer, data);
    }
  }, [buffer, data]);

  // Callbacks
  function onSelection(name: string) {
    // For now, the only markers are functions.
    setSelect({ function: name });
  }

  // Component
  return (
    <>
      <Vfill>
        <Text
          buffer={buffer}
          mode="text"
          theme="default"
          onSelection={onSelection}
          readOnly
        />
      </Vfill>
    </>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.astinfo"
    label="Information"
    title="AST Information"
  >
    <ASTinfo />
  </Component>
);

// --------------------------------------------------------------------------
