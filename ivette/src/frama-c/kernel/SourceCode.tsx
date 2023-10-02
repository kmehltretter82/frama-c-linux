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
import * as Editor from 'dome/text/editor';
import * as Labels from 'dome/controls/labels';
import * as Settings from 'dome/data/settings';
import * as Buttons from 'dome/controls/buttons';
import * as Dialogs from 'dome/dialogs';
import * as Toolbars from 'dome/frame/toolbars';

import { Selection, Document } from 'dome/text/editor';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Status from 'frama-c/kernel/Status';
import * as Ast from 'frama-c/kernel/api/ast';

import * as Ivette from 'ivette';
import * as Preferences from 'ivette/prefs';



// -----------------------------------------------------------------------------
//  Utilitary types and functions
// -----------------------------------------------------------------------------

// Recovering the cursor position as a line and a column.
interface Position { line: number, column: number }
function getCursorPosition(view: Editor.View): Position {
  const pos = view?.state.selection.main;
  if (!view || !pos) return { line: 1, column: 1 };
  const line = view.state.doc.lineAt(pos.from);
  const column = pos.from - line.from + 1;
  return { line: line.number, column };
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

// Those fields contain the source code and the file name.
const Source = Editor.createTextField<string>('', (s) => s);
const File = Editor.createField<string>('');

// This field contains the command use to start the external editor.
const Command = Editor.createField<string>('');

// These field contains a callback that returns the source of a location.
type GetSource = (loc: States.Location) => Ast.source | undefined;
const GetSource = Editor.createField<GetSource>(() => undefined);

// We keep track of the cursor location (i.e the location that is under the
// current CodeMirror cursor) and the ivette location (i.e the locations as
// seen by the outside world). Keeping track of both of them together force
// their update in one dispatch, which prevents strange bugs.
interface Locations { cursor?: States.Location, current: States.Location }

// The Locations field. When given Locations, it will update the cursor field if
// and only if the new cursor location is not undefined. It simplifies the
// update in the SourceCode component itself.
const Locations = createLocationsField();
function createLocationsField(): Editor.Field<Locations> {
  const noField = { cursor: undefined, current: {} };
  const field = Editor.createField<Locations>(noField);
  const set: Editor.Set<Locations> = (view, toBe) => {
    const hasBeen = field.get(view?.state);
    const cursor = toBe.cursor ?? hasBeen.cursor;
    field.set(view, { cursor, current: toBe.current });
  };
  return { ...field, set };
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Synchronisation with the outside world
// -----------------------------------------------------------------------------

// Update the outside world when the user click somewhere in the source code.
const SyncOnUserSelection = createSyncOnUserSelection();
function createSyncOnUserSelection(): Editor.Extension {
  const actions = { cmd: Command };
  const deps = { file: File, selection: Selection, doc: Document, ...actions };
  return Editor.createEventHandler(deps, {
    mouseup: async ({ file, cmd }, view, event) => {
      if (!view || file === '') return;
      const pos = getCursorPosition(view);
      const cursor = { file, line: pos.line, column: pos.column };
      try {
        const marker = await Server.send(Ast.getMarkerAt, cursor);
        if (marker) {
          // The forced reload should NOT be necessary but... It is...
          await Server.send(Ast.reloadMarkerAttributes, null);
          States.setSelected(marker);
          const location = States.getCurrentLocation();
          Locations.set(view, { cursor: location, current: location });
        }
      } catch {
        setError('Failure');
      }
      if (event.ctrlKey) edit(file, pos, cmd);
    }
  });
}

// Update the cursor position when the outside world changes the selected
// location.
const SyncOnOutsideSelection = createSyncOnOutsideSelection();
function createSyncOnOutsideSelection(): Editor.Extension {
  const deps = { locations: Locations, get: GetSource };
  return Editor.createViewUpdater(deps, ({ locations, get }, view) => {
    const { cursor, current } = locations;
    if (current === undefined || current === cursor) return;
    const source = get(current); if (!source) return;
    const newDecl =
      current.scope !== cursor?.scope && current.marker === undefined;
    const onTop = cursor === undefined || newDecl;
    Locations.set(view, { cursor: current, current });
    Editor.selectLine(view, source.line, onTop, false);
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Context menu
// -----------------------------------------------------------------------------

// This events handler takes care of the context menu.
const ContextMenu = createContextMenu();
function createContextMenu(): Editor.Extension {
  const deps = { file: File, command: Command };
  return Editor.createEventHandler(deps, {
    contextmenu: ({ file, command }, view) => {
      if (file === '') return;
      const label = 'Open file in an external editor';
      const pos = getCursorPosition(view);
      Dome.popupMenu([ { label, onClick: () => edit(file, pos, command) } ]);
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

// Build a callback that retrieves a location's source information.
function useSourceGetter(): GetSource {
  const getAttr = States.useSyncArrayGetter(Ast.markerAttributes);
  const getDecl = States.useSyncArrayGetter(Ast.declAttributes);
  return React.useCallback(({ scope, marker }) => {
    const { sloc, scope: markerDecl } = getAttr(marker) ?? {};
    if (sloc) return sloc;
    const { source } = getDecl(scope ?? markerDecl) ?? {};
    return source;
  }, [getAttr, getDecl]);
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Source Code component
// -----------------------------------------------------------------------------

// Necessary extensions.
const extensions: Editor.Extension[] = [
  Source,
  Editor.Search,
  Editor.ReadOnly,
  Editor.Selection,
  Editor.LineNumbers,
  Editor.LanguageHighlighter,
  Editor.HighlightActiveLine,
  SyncOnUserSelection,
  SyncOnOutsideSelection,
  ContextMenu,
  Locations.structure,
];

// The component in itself.
export default function SourceCode(): JSX.Element {
  const [fontSize] = Settings.useGlobalSettings(Preferences.EditorFontSize);
  const [command] = Settings.useGlobalSettings(Preferences.EditorCommand);
  const { view, Component } = Editor.Editor(extensions);
  const current = States.useCurrentLocation();
  const getSource = useSourceGetter();
  const file = getSource(current)?.file ?? '';
  const filename = Path.parse(file).base;
  const pos = getCursorPosition(view);
  const source = useFctSource(file);

  React.useEffect(() => GetSource.set(view, getSource), [view, getSource]);
  React.useEffect(() => File.set(view, file), [view, file]);
  React.useEffect(() => Source.set(view, source), [view, source]);
  React.useEffect(() => Command.set(view, command), [view, command]);
  React.useEffect(() => Locations.set(view, { current }), [view, current]);

  const externalEditorTitle =
    'Open the source file in an external editor.';

  const shortcuts =
    'Ctrl+click: open file in an external editor at the selected location.\n'
    + 'Alt+f: search for text or regexp.\n'
    + 'Alt+g: go to line.';

  const shortcutsTitle = 'Useful shortcuts:\n' + shortcuts;

  async function displayShortcuts(): Promise<void> {
    await Dialogs.showMessageBox({
      buttons: [{ label: "Ok" }],
      details: shortcuts,
      message: 'Useful shortcuts'
    });
  }

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
        <Toolbars.Filler />
        <Buttons.IconButton
          icon="HELP"
          onClick={displayShortcuts}
          title={shortcutsTitle}
        />
        <Toolbars.Inset/>
      </Ivette.TitleBar>
      <Component style={{ fontSize: `${fontSize}px` }} />
    </>
  );
}

// -----------------------------------------------------------------------------
