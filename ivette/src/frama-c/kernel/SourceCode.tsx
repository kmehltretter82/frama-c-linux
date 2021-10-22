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
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import * as Dome from 'dome';
import * as System from 'dome/system';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { TitleBar } from 'ivette';
import * as Preferences from 'ivette/prefs';
import { functions, markerInfo, getMarkerAt } from 'frama-c/api/kernel/ast';
import { Code } from 'dome/controls/labels';
import { Hfill } from 'dome/layout/boxes';
import { IconButton } from 'dome/controls/buttons';
import * as Path from 'path';
import * as Settings from 'dome/data/settings';
import * as Status from 'frama-c/kernel/Status';

import CodeMirror from 'codemirror/lib/codemirror';
import 'codemirror/addon/selection/active-line';
import 'codemirror/addon/dialog/dialog.css';
import 'codemirror/addon/search/search';
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
  const [selection, updateSelection] = States.useSelection();
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
  const onError = () => { if (file) errorMsg(); return ''; };
  const read = () => System.readFile(file).catch(onError);
  const text = React.useMemo(read, [file, onError]);
  const { result } = Dome.usePromise(text);
  React.useEffect(() => buffer.setValue(result), [buffer, result]);
  React.useEffect(() => buffer.setCursorOnTop(line), [buffer, line, result]);

  /* CodeMirror types used to bind callbacks to extraKeys. */
  type position = CodeMirror.Position;
  type editor = CodeMirror.Editor;

  async function select(_: editor, pos?: position) {
    if (file === '' || !pos) return;
    const arg = [file, pos.line + 1, pos.ch + 1];
    const [fct, marker] = await Server.send(getMarkerAt, arg);
    if (fct || marker)
      updateSelection({ location: { fct, marker } });
  }

  const [command] = Settings.useGlobalSettings(Preferences.EditorCommand);
  async function launchEditor(_?: editor, pos?: position) {
    if (file !== '') {
      const selectedLine = pos ? (pos.line + 1).toString() : '1';
      const selectedChar = pos ? (pos.ch + 1).toString() : '1';
      const cmd = command
        .replace('%s', file)
        .replace('%n', selectedLine)
        .replace('%c', selectedChar);
      const args = cmd.split(' ');
      const prog = args.shift();
      if (prog) System.spawn(prog, args).catch(() => {
        Status.setMessage({
          text: `An error has occured when opening the external editor ${prog}`,
          kind: 'error',
        });
      });
    }
  }

  async function contextMenu(editor?: editor, pos?: position) {
    if (file !== '') {
      const items = [
        {
          label: 'Open file in an external editor',
          onClick: () => launchEditor(editor, pos),
        },
      ];
      Dome.popupMenu(items);
    }
  }

  const externalEditorTitle =
    'Open the source file in an external editor.\nA Ctrl-click '
    + 'in the source code opens the editor at the selected location.'
    + '\nThe editor used can be configured in Ivette settings.';

  // Building the React component.
  return (
    <>
      <TitleBar>
        <IconButton
          icon="DUPLICATE"
          visible={file !== ''}
          onClick={launchEditor}
          title={externalEditorTitle}
        />
        <Code title={file} style={{ padding: '5px' }}>{filename}</Code>
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
        extraKeys={{
          LeftClick: select as (_: CodeMirror.Editor) => void,
          'Alt-F': 'findPersistent',
          'Ctrl-LeftClick': launchEditor as (_: CodeMirror.Editor) => void,
          RightClick: contextMenu as (_: CodeMirror.Editor) => void,
        }}
        readOnly
      />
    </>
  );

}

// --------------------------------------------------------------------------
