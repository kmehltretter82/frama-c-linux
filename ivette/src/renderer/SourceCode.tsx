// --------------------------------------------------------------------------
// --- Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import { readFile } from 'dome/system';
import * as Json from 'dome/data/json';
import * as Settings from 'dome/data/settings';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { IconButton } from 'dome/controls/buttons';
import { Component, TitleBar } from 'frama-c/LabViews';
import { functions, markerInfo } from 'frama-c/api/kernel/ast';
import { source } from 'frama-c/api/kernel/services';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';
import 'codemirror/addon/selection/active-line';
import 'codemirror/addon/dialog/dialog.css';
import 'codemirror/addon/dialog/dialog';
import 'codemirror/addon/search/searchcursor';
import 'codemirror/addon/search/search';
import 'codemirror/addon/search/jump-to-line';

import { THEMES, ThemeSC, FontSizeSC } from './Preferences';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const D = new Dome.Debug('Source Code');

// --------------------------------------------------------------------------
// --- Source Code Printer
// --------------------------------------------------------------------------

const SourceCode = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [theme, setTheme] = Settings.useGlobalSettings(ThemeSC);
  const [fontSize, setFontSize] = Settings.useGlobalSettings(FontSizeSC);
  const [wrapText, flipWrapText] = Dome.useFlipSettings('SourceCode.wrapText');

  const markersInfo = States.useSyncArray(markerInfo);
  const functionsData = States.useSyncArray(functions).getArray();

  const [selection] = States.useSelection();
  const theFunction = selection?.current?.function;
  const theMarker = selection?.current?.marker;

  const currentFile = React.useRef<string>();

  React.useEffect(() => {
    // Async source file loading and jump to line/location.
    async function loadSourceCode(sloc?: source) {
      if (sloc) {
        const { file, line } = sloc;
        try {
          if (file !== currentFile.current) {
            currentFile.current = file;
            const content = await readFile(file);
            buffer.setValue(content);
          }
          buffer.forEach((cm) => { cm.setCursor(line - 1); });
        } catch (err) {
          D.error(`Fail to load source code file ${file}.`);
        }
      }
    }
    // Actual source code loading upon function or marker update.
    const sloc =
      /* Non-empty [selection] has defined either marker or function: we give
         precedence to marker as it provides more precise source location. */
      (theMarker &&
        markersInfo.getData(theMarker as Json.key<'#markerInfo'>)?.sloc)
      ??
      (theFunction && functionsData.find((e) => e.name === theFunction)?.sloc);
    if (sloc) {
      loadSourceCode(sloc);
    } else {
      currentFile.current = undefined;
      buffer.clear();
    }
  }, [buffer, functionsData, markersInfo, theFunction, theMarker]);

  // Callbacks
  const zoomIn = () => fontSize < 48 && setFontSize(fontSize + 2);
  const zoomOut = () => fontSize > 4 && setFontSize(fontSize - 2);

  // Theme Popup
  const selectTheme = (id?: string) => id && setTheme(id);
  const themeItem = (th: { id: string; label: string }) => (
    { checked: th.id === theme, ...th }
  );
  const themePopup = () => Dome.popupMenu(THEMES.map(themeItem), selectTheme);

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
          onClick={flipWrapText}
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
        lineNumbers={!!theFunction}
        styleActiveLine={!!theFunction}
        extraKeys={{ 'Alt-F': 'findPersistent' }}
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
    id="frama-c.sourcecode"
    label="Source Code"
    title="Original source code"
  >
    <SourceCode />
  </Component>
);

// --------------------------------------------------------------------------
