// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Select, IconButton } from 'dome/controls/buttons';
import { Space } from 'dome/frame/toolbars';
import { Component, TitleBar } from 'frama-c/LabViews';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

const THEMES = [
  { id: "default", label: "Default" },
  { id: "ambiance", label: "Ambiance" },
  { id: "solarized light", label: "Solarized Light" },
  { id: "solarized dark", label: "Solarized Dark" }
];

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

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const printed = React.useRef();
  const [select, setSelect] = States.useSelection();
  const [theme, setTheme] = Dome.useGlobalSetting('AST.theme', 'default');
  const [fontSize, setFontSize] = Dome.useGlobalSetting('AST.fontSize', 12);
  const [lineWrapping, setLineWrapping] = Dome.useSwitch('ASTview.lineWrapping', false);

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
  const zoomIn = () => setFontSize(fontSize + 2);
  const zoomOut = () => setFontSize(fontSize - 2);
  const onSelection = (marker: any) => setSelect({ marker });

  // Theme Popup

  const checkTheme = (th: { id: string }) => ({ checked: th.id === theme, ...th });
  const selectTheme = (id?: string) => id && setTheme(id);
  const themePopup = () => Dome.popupMenu(THEMES.map(checkTheme), selectTheme);

  // Component
  return (
    <>
      <TitleBar>
        <IconButton icon="ZOOM.OUT" onClick={zoomOut} />
        <IconButton icon="ZOOM.IN" onClick={zoomIn} />
        <IconButton icon="CODE" onClick={themePopup} />
        <IconButton icon="WRAPTEXT" selected={lineWrapping} onClick={setLineWrapping} />
      </TitleBar>
      <Text
        buffer={buffer}
        mode="text/x-csrc"
        theme={theme}
        fontSize={fontSize}
        lineWrapping={lineWrapping}
        selection={theMarker}
        onSelection={onSelection}
        readOnly
      />
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
