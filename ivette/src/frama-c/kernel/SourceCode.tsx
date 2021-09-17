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
import { functions, markerInfo } from 'frama-c/api/kernel/ast';
import { Code } from 'dome/controls/labels';
import { Hfill } from 'dome/layout/boxes';
import * as Path from 'path';

import 'codemirror/addon/selection/active-line';
import 'codemirror/addon/dialog/dialog.css';
import 'codemirror/addon/search/searchcursor';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const D = new Dome.Debug('Source Code');

// --------------------------------------------------------------------------
// --- Source Code Printer
// --------------------------------------------------------------------------

// The SourceCode component, producing the GUI part showing the source code
// corresponding to the selected function.
export default function SourceCode() {

  // Hooks
  const [buffer] = React.useState(new RichTextBuffer());
  const [selection] = States.useSelection();
  const theFunction = selection?.current?.fct;
  const theMarker = selection?.current?.marker;
  const markersInfo = States.useSyncArray(markerInfo);
  const functionsData = States.useSyncArray(functions).getArray();

  // Retrieving the file name and the line number from the selection and the
  // synchronized tables.
  const sloc =
    (theMarker && markersInfo.getData(theMarker)?.sloc) ??
    (theFunction && functionsData.find((e) => e.name === theFunction)?.sloc);
  const file = sloc ? sloc.file : '';
  const line = sloc ? sloc.line : 0;
  const filename = Path.parse(file).base;

  // Title bar buttons, along with the parameters for our text.
  const { buttons: themeButtons, theme, fontSize, wrapText } =
    Preferences.useThemeButtons({
      target: 'Source Code',
      theme: Preferences.SourceTheme,
      fontSize: Preferences.SourceFontSize,
      wrapText: Preferences.AstWrapText,
      disabled: !theFunction,
    });

  // Updating the buffer content.
  const errorMsg = () => { D.error(`Fail to load source code file ${file}`); };
  const onError = () => { if (file) errorMsg(); };
  const setValue = (text: string) => buffer.setValue(text);
  const setCursor = () => buffer.setCursorOnTop(line);
  const text = React.useMemo(() => readFile(file), [file]);
  Dome.usePromise(text.then(setValue).then(setCursor).catch(onError));

  // Building the React component.
  return (
    <>
      <TitleBar>
        <Code title={file}>{filename}</Code>
        <Hfill />
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
