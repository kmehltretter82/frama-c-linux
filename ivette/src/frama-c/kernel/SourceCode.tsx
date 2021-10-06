/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Source Code
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import { readFile } from 'dome/system';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { TitleBar } from 'ivette';
import * as Preferences from 'ivette/prefs';
import { functions, markerInfo, source } from 'frama-c/api/kernel/ast';

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

export default function SourceCode() {

  // Hooks
  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [selection] = States.useSelection();
  const theFunction = selection?.current?.fct;
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
      /* markers have more precise source location */
      (theMarker && markersInfo.getData(theMarker)?.sloc)
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

}

// --------------------------------------------------------------------------
