// --------------------------------------------------------------------------
// --- Source Code
// --------------------------------------------------------------------------

import React from 'react';
import _ from 'lodash';
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
// --- Rich Text Printer
// --------------------------------------------------------------------------

async function loadSourceCode(buffer: RichTextBuffer, sloc: source) {
  const { file, line } = sloc;
  try {
    const content = await readFile(file);
    buffer.setValue(content);
    buffer.scroll(line);
    buffer.getDoc().setCursor(line);
  } catch (err) {
    D.error(`Fail to load source code file ${file}.`);
  }
}

// --------------------------------------------------------------------------
// --- Source Code Printer
// --------------------------------------------------------------------------

const SourceCode = () => {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [selection] = States.useSelection();
  const [theme, setTheme] = Settings.useGlobalSettings(ThemeSC);
  const [fontSize, setFontSize] = Settings.useGlobalSettings(FontSizeSC);
  const [wrapText, flipWrapText] = Dome.useFlipSettings('SourceCode.wrapText');

  const markersInfo = States.useSyncArray(markerInfo);
  const fcts = States.useSyncArray(functions).getArray();

  const theFunction = selection?.current?.function;
  const currentFunction = React.useRef<string | undefined>();

  const theMarker = selection?.current?.marker;
  const currentMarker = React.useRef<string | undefined>();

  // Hook: async loading
  React.useEffect(() => {
    if (theMarker && currentMarker.current !== theMarker) {
      currentMarker.current = theMarker;
      const markerId = (theMarker as Json.key<'#markerInfo'>);
      const markerIdInfo = markersInfo.getData(markerId);
      if (markerIdInfo) {
        loadSourceCode(buffer, markerIdInfo.sloc);
      }
    } else if (theFunction && currentFunction.current !== theFunction) {
      currentFunction.current = theFunction;
      const currentFunctionData = _.find(fcts, (e) => e.name === theFunction);
      if (currentFunctionData) {
        loadSourceCode(buffer, currentFunctionData.sloc);
      }
    } else
      buffer.clear();
  }, [buffer, fcts, markersInfo, theFunction, theMarker]);

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
        readOnly
        styleActiveLine={!!theFunction}
        extraKeys={{ 'Alt-F': 'findPersistent' }}
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
