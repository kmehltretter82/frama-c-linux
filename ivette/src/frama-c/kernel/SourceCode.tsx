/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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

import React from 'react';
import * as Path from 'path';

import * as Dome from 'dome';
import * as System from 'dome/system';
import * as Boxes from 'dome/layout/boxes';
import * as Editor from 'dome/text/editor';
import * as Labels from 'dome/controls/labels';
import * as Settings from 'dome/data/settings';
import * as Buttons from 'dome/controls/buttons';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Status from 'frama-c/kernel/Status';
import * as Ast from 'frama-c/kernel/api/ast';

import * as Ivette from 'ivette';
import * as Preferences from 'ivette/prefs';



// -----------------------------------------------------------------------------
//  Utilitary types and functions
// -----------------------------------------------------------------------------

// An alias type for functions and locations.
type Fct = string | undefined;
type Marker = string | undefined;

// Recovering the cursor position as a line and a column.
interface Position { line: number, column: number }
function getCursorPosition(view: Editor.View): Position {
  const pos = view?.state.selection.main;
  if (!view || !pos) return { line: 1, column: 1 };
  const line = view.state.doc.lineAt(pos.from).number;
  const column = (pos.goalColumn ?? 0) + 1;
  return { line, column };
}

// Error messages.
function setError(text: string): void {
  Status.setMessage({ text, kind: 'error' });
}

// Function launching the external editor at the currently selected position.
async function edit(file: string, pos: Position, cmd: string): Promise<void> {
  if (file === '') return;
  const args = cmd
    .replace('%s', file)
    .replace('%n', pos.line.toString())
    .replace('%c', pos.column.toString())
    .split(' ');
  const prog = args.shift(); if (!prog) return;
  const text = `An error has occured when opening the external editor ${prog}`;
  System.spawn(prog, args).catch(() => setError(text));
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Fields declarations
// -----------------------------------------------------------------------------

// The Ivette selection must be updated by the CodeMirror plugin. This field
// adds the callback in the CodeMirror internal state.
type UpdateSelection = (a: States.SelectionActions) => void;
const UpdateSelection = Editor.createField<UpdateSelection>(() => { return; });

// Those fields contain the source code and the file name.
const Source = Editor.createTextField<string>('', (s) => s);
const File = Editor.createField<string>('');

// This field contains the command use to start the external editor.
const Command = Editor.createField<string>('');

// This field contains the currently selected function.
const Fct = Editor.createField<Fct>(undefined);

// This field contains the currently selected marker.
const Marker = Editor.createField<Marker>(undefined);

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Context menu and source interactions
// -----------------------------------------------------------------------------

// This events handler takes care of the context menu, of the selection in the
// source code (updating the global Ivette's selection) and of the meta
// selection (with the ctrl modificator) to launch the external editor.
const EventsHandler = createEventsHandler();
function createEventsHandler(): Editor.Extension {
  const deps = { file: File, command: Command, update: UpdateSelection };
  return Editor.createEventHandler(deps, {
    contextmenu: ({ file, command }, view) => {
      if (file === '') return;
      const label = 'Open file in an external editor';
      const pos = getCursorPosition(view);
      Dome.popupMenu([ { label, onClick: () => edit(file, pos, command) } ]);
    },
    mouseup: ({ file, command, update }, view, event) => {
      if (file === '') return;
      const pos = getCursorPosition(view);
      Server
        .send(Ast.getMarkerAt, [file, pos.line, pos.column])
        .then(([fct, marker]) => {
          if (fct || marker) update({ location: { fct, marker } });
        })
        .catch(() => setError('Failed to request to Frama-C server'));
      if (event.ctrlKey) edit(file, pos, command);
    },
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Server requests
// -----------------------------------------------------------------------------

// Server request handler returning the source code.
function useFctSource(file: string): string {
  const req = React.useMemo(() => System.readFile(file), [file]);
  const { result } = Dome.usePromise(req);
  return result ?? '';
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Source Code component
// -----------------------------------------------------------------------------

// Necessary extensions.
const extensions: Editor.Extension[] = [
  Source,
  Editor.Selection,
  Editor.LineNumbers,
  Editor.LanguageHighlighter,
  Editor.HighlightActiveLine,
  EventsHandler,
];

function useMarkerLocation(m: Ast.marker | undefined): Ast.source | undefined {
  const markersInfo = States.useSyncArray(Ast.markerInfo);
  if (m === undefined || m === '') return undefined;
  return markersInfo.getData(m)?.sloc;
}

function useFunctionLocation(fct: string | undefined): Ast.source | undefined {
  const functionsData = States.useSyncArray(Ast.functions).getArray();
  if (fct === undefined || fct === '') return undefined;
  return functionsData.find((e) => e.name === fct)?.sloc;
}

// The component in itself.
export default function SourceCode(): JSX.Element {
  const [fontSize] = Settings.useGlobalSettings(Preferences.EditorFontSize);
  const [command] = Settings.useGlobalSettings(Preferences.EditorCommand);
  const { view, Component } = Editor.Editor(extensions);
  const [selection, update] = States.useSelection();
  const marker = selection?.current?.marker;
  const fct = selection?.current?.fct;
  const displayedFct = React.useRef<string | undefined>(undefined);

  const markerSloc = useMarkerLocation(marker);
  const fctSloc = useFunctionLocation(fct);
  const file = fctSloc?.file ?? '';
  const filename = Path.parse(file).base;
  const pos = getCursorPosition(view);
  const source = useFctSource(file);

  React.useEffect(() => Source.set(view, source), [view, source]);
  React.useEffect(() => UpdateSelection.set(view, update), [view, update]);
  React.useEffect(() => Command.set(view, command), [view, command]);
  React.useEffect(() => File.set(view, file), [view, file]);

  React.useEffect(() => {
    const notDisplayedFct = fct !== displayedFct.current;
    const line = notDisplayedFct ? fctSloc?.line : markerSloc?.line;
    if (line) Editor.selectLine(view, line, notDisplayedFct);
    displayedFct.current = fct;
  }, [view, markerSloc, fctSloc, displayedFct, fct]);

  const externalEditorTitle =
    'Open the source file in an external editor.\nA Ctrl-click '
    + 'in the source code opens the editor at the selected location.'
    + '\nThe editor used can be configured in Ivette settings.';

  return (
    <>
      <Ivette.TitleBar>
        <Buttons.IconButton
          icon="DUPLICATE"
          visible={file !== ''}
          onClick={() => edit(file, pos, command)}
          title={externalEditorTitle}
        />
        <Labels.Code title={file}>{filename}</Labels.Code>
        <Boxes.Hfill />
      </Ivette.TitleBar>
      <Component style={{ fontSize: `${fontSize}px` }} />
    </>
  );
}

// -----------------------------------------------------------------------------
