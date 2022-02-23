/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module ivette/prefs
 */

import React from 'react';
import * as Dome from 'dome';
import * as Themes from 'dome/themes';
import * as Toolbar from 'dome/frame/toolbars';
import * as Settings from 'dome/data/settings';
import { IconButton } from 'dome/controls/buttons';
import 'codemirror/mode/clike/clike';

// --------------------------------------------------------------------------
// --- AST View Preferences
// --------------------------------------------------------------------------

export const AstFontSize = new Settings.GNumber('ASTview.fontSize', 12);
export const AstWrapText = new Settings.GFalse('ASTview.wrapText');
export const SourceFontSize = new Settings.GNumber('SourceCode.fontSize', 12);
export const SourceWrapText = new Settings.GFalse('SourceCode.wrapText');

/* -------------------------------------------------------------------------- */
/* --- Theme Switcher Button                                              --- */
/* -------------------------------------------------------------------------- */

export function ThemeSwitch(): JSX.Element {
  const [theme, setTheme] = Themes.useColorTheme();
  const other = theme === 'dark' ? 'light' : 'dark';
  const position = theme === 'dark' ? 'left' : 'right';
  const title = `Switch to ${other} theme`;
  const onChange = (): void => setTheme(other);
  return (
    <Toolbar.Switch
      disabled={!Dome.DEVEL}
      title={title}
      position={position}
      onChange={onChange}
    />
  );
}

// --------------------------------------------------------------------------
// --- Editor Icon Buttons
// --------------------------------------------------------------------------

export interface EditorProps {
  fontSize: Settings.GlobalSettings<number>;
  wrapText: Settings.GlobalSettings<boolean>;
  disabled?: boolean;
}

export interface EditorControls {
  buttons: React.ReactNode;
  fontSize: number;
  wrapText: boolean;
}

export function useEditorButtons(props: EditorProps): EditorControls {
  const { disabled = false } = props;
  const [fontSize, setFontSize] = Settings.useGlobalSettings(props.fontSize);
  const [wrapText, setWrapText] = Settings.useGlobalSettings(props.wrapText);
  const zoomIn = (): void => setFontSize(fontSize + 2);
  const zoomOut = (): void => setFontSize(fontSize - 2);
  const flipWrapText = (): void => setWrapText(!wrapText);
  return {
    fontSize,
    wrapText,
    buttons: [
      <IconButton
        key="zoom.out"
        icon="ZOOM.OUT"
        onClick={zoomOut}
        enabled={fontSize > 4}
        disabled={disabled}
        title="Decrease font size"
      />,
      <IconButton
        key="zoom.in"
        icon="ZOOM.IN"
        onClick={zoomIn}
        enabled={fontSize < 48}
        disabled={disabled}
        title="Increase font size"
      />,
      <IconButton
        key="wrap"
        icon="WRAPTEXT"
        selected={wrapText}
        disabled={disabled}
        onClick={flipWrapText}
        title="Wrap text"
      />,
    ],
  };
}

// --------------------------------------------------------------------------
// --- Editor configuration
// --------------------------------------------------------------------------

export const EditorCommand =
  new Settings.GString('Editor.Command', 'emacs +%n:%c %s');

export interface EditorCommandProps {
  command: Settings.GlobalSettings<string>;
}

// --------------------------------------------------------------------------
