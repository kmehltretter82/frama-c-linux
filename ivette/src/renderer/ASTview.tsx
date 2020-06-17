// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { IconButton } from 'dome/controls/buttons';
import { Component, TitleBar } from 'frama-c/LabViews';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

const THEMES = [
  { id: 'default', label: 'Default' },
  { id: 'ambiance', label: 'Ambiance' },
  { id: 'solarized light', label: 'Solarized Light' },
  { id: 'solarized dark', label: 'Solarized Dark' },
];

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const PP = new Dome.PP('AST View');

// --------------------------------------------------------------------------
// --- Rich Text Printer
// --------------------------------------------------------------------------

async function loadAST(
  buffer: RichTextBuffer, theFunction?: string, theMarker?: string,
) {
  buffer.clear();
  if (theFunction) {
    buffer.log('// Loading', theFunction, '…');
    (async () => {
      try {
        const data = await Server.GET({
          endpoint: 'kernel.ast.printFunction',
          params: theFunction,
        });
        buffer.operation(() => {
          buffer.clear();
          if (!data) {
            buffer.log('// No code for function', theFunction);
          }
          buffer.printTextWithTags(data);
          if (theMarker)
            buffer.scroll(theMarker, undefined);
        });
      } catch (err) {
        PP.error(
          'Fail to retrieve the AST of function', theFunction,
          'marker:', theMarker, err,
        );
      }
    })();
  }
}

// --------------------------------------------------------------------------
// --- AST Printer
// --------------------------------------------------------------------------

const ASTview = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const printed: React.MutableRefObject<string | undefined> = React.useRef();
  const [selection, updateSelection] = States.useSelection();
  const [theme, setTheme] = Dome.useGlobalSetting('ASTview.theme', 'default');
  const [fontSize, setFontSize] = Dome.useGlobalSetting('ASTview.fontSize', 12);
  const [wrapText, setWrapText] = Dome.useSwitch('ASTview.wrapText', false);
  const markers = States.useSyncArray('kernel.ast.markerKind');

  const theFunction = selection?.current?.function;
  const theMarker = selection?.current?.marker;

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
  const zoomIn = () => fontSize < 48 && setFontSize(fontSize + 2);
  const zoomOut = () => fontSize > 4 && setFontSize(fontSize - 2);

  function onTextSelection(id: string) {
    if (selection.current) {
      const location = { ...selection.current, marker: id };
      updateSelection({ location });
    }
  }

  function onContextMenu(id: string) {
    const marker = markers[id];
    if (marker && marker.kind === 'function') {
      const item = {
        label: `Go to definition of ${marker.name}`,
        onClick: () => {
          const location = { function: marker.name };
          updateSelection({ location });
        },
      };
      Dome.popupMenu([item]);
    }
  }

  // Theme Popup
  const selectTheme = (id?: string) => id && setTheme(id);
  const checkTheme =
    (th: { id: string }) => ({ checked: th.id === theme, ...th });
  const themePopup =
    () => Dome.popupMenu(THEMES.map(checkTheme), selectTheme);

  // Component
  return (
    <>
      <TitleBar>
        <IconButton
          icon="ZOOM.OUT"
          onClick={zoomOut}
          disabled={!theFunction}
          title="Decrease font size"
        />
        <IconButton
          icon="ZOOM.IN"
          onClick={zoomIn}
          disabled={!theFunction}
          title="Increase font size"
        />
        <IconButton
          icon="PAINTBRUSH"
          onClick={themePopup}
          title="Choose theme"
        />
        <IconButton
          icon="WRAPTEXT"
          selected={wrapText}
          onClick={setWrapText}
          title="Wrap text"
        />
      </TitleBar>
      <Text
        buffer={buffer}
        mode="text/x-csrc"
        theme={theme}
        fontSize={fontSize}
        lineWrapping={wrapText}
        selection={theMarker}
        onSelection={onTextSelection}
        onContextMenu={onContextMenu}
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
    title="Normalized source code representation"
  >
    <ASTview />
  </Component>
);

// --------------------------------------------------------------------------
