// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Select, Switch, IconButton } from 'dome/controls/buttons';
import * as Toolbars from 'dome/frame/toolbars';
import { Component, TitleBar } from 'frama-c/LabViews';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

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
      buffer.operation(() => {
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

function useGlobal(param: string, dft: any) {
  return Dome.useGlobalSetting(`ASTview.${param}`, dft);
}

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const printed = React.useRef();
  const [select, setSelect] = States.useSelection();
  const theFunction = select && select.function;
  const theMarker = select && select.marker;
  const [theme, setTheme] = useGlobal('theme', 'default');
  const [lineWrapping, setLineWrapping] = useGlobal('lineWrapping', false);
  const [fontSize, setFontSize] = useGlobal('fontSize', 12);

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

  const titlebar = (
    <TitleBar>
      <Select
        value={theme}
        onChange={(name: string) => setTheme(name)}
      >
        <option value="default" label="Default" />
        <option value="ambiance" label="Ambiance" />
        <option value="solarized light" label="Solarized light" />
        <option value="solarized dark" label="Solarized dark" />
      </Select>
      <Toolbars.Space />
      <IconButton
        icon="MINUS"
        title="Decrease the font size"
        onClick={() => setFontSize(fontSize - 2)}
      />
      <IconButton
        icon="PLUS"
        title="increase the font size"
        onClick={() => setFontSize(fontSize + 2)}
      />
      <Toolbars.Space />
      <Switch
        label="Line wrapping"
        title="Change line wrapping mode"
        value={lineWrapping}
        onChange={() => setLineWrapping(!lineWrapping)}
      />
      <Toolbars.Space />
    </TitleBar>
  );

  // Component
  return (
    <>
      {titlebar}
      <Vfill style={{ fontSize }}>
        <Text
          buffer={buffer}
          mode="text/x-csrc"
          theme={theme}
          lineWrapping={lineWrapping}
          selection={theMarker}
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
    id="frama-c.astview"
    label="AST"
    title="Normalized source code representation."
  >
    <ASTview />
  </Component>
);

// --------------------------------------------------------------------------
