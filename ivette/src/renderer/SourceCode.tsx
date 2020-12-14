// --------------------------------------------------------------------------
// --- Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import { readFile } from 'dome/system';
import * as Json from 'dome/data/json';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { Component, TitleBar } from 'frama-c/LabViews';
import { functions, markerInfo } from 'frama-c/api/kernel/ast';
import { source } from 'frama-c/api/kernel/services';
import * as Preferences from './Preferences';

import 'codemirror/addon/selection/active-line';
import 'codemirror/addon/dialog/dialog.css';
import 'codemirror/addon/dialog/dialog';
import 'codemirror/addon/search/searchcursor';
import 'codemirror/addon/search/search';
import 'codemirror/addon/search/jump-to-line';

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
  const [selection] = States.useSelection();
  const theFunction = selection?.current?.function;
  const theMarker = selection?.current?.marker;
  const { buttons: themeButtons, theme, fontSize, wrapText } =
    Preferences.useThemeButtons({
      target: 'Source Code',
      theme: Preferences.SourceTheme,
      fontSize: Preferences.SourceFontSize,
      wrapText: Preferences.AstWrapText,
      disabled: !theFunction,
    });

  const markersInfo = States.useSyncArray(markerInfo);
  const functionsData = States.useSyncArray(functions).getArray();

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

  // Component
  return (
    <>
      <TitleBar>
        {themeButtons}
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
