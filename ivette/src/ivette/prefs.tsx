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

/* eslint-disable @typescript-eslint/explicit-function-return-type */

// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module ivette/prefs
 */

import React from 'react';

import { usePromise } from 'dome/dome';
import * as Settings from 'dome/data/settings';
import { IconButton } from 'dome/controls/buttons';

import 'codemirror/mode/clike/clike';
import '../colors/dark-code.css';
import { ipcRenderer } from 'electron';

export const THEMES = [
  { id: 'light', label: 'Light' },
  { id: 'dark', label: 'Dark' },
  { id: 'system', label: 'System' },
];

// --------------------------------------------------------------------------
// --- AST View Preferences
// --------------------------------------------------------------------------

export const ColorTheme = new Settings.GString('color-theme', 'system');
export const AstFontSize = new Settings.GNumber('ASTview.fontSize', 12);
export const AstWrapText = new Settings.GFalse('ASTview.wrapText');
export const SourceFontSize = new Settings.GNumber('SourceCode.fontSize', 12);
export const SourceWrapText = new Settings.GFalse('SourceCode.wrapText');

export interface ThemeProps {
  target: string;
  fontSize: Settings.GlobalSettings<number>;
  wrapText: Settings.GlobalSettings<boolean>;
  disabled?: boolean;
}

// --------------------------------------------------------------------------
// --- Icon Buttons
// --------------------------------------------------------------------------

export interface ThemeControls {
  buttons: React.ReactNode;
  theme: string;
  fontSize: number;
  wrapText: boolean;
}

export function forceThemeUpdate(theme: string) {
  ipcRenderer.invoke('theme-color:switch', theme);
}

ipcRenderer.on('dome.ipc.settings.defaults', () => {
  forceThemeUpdate('system');
});

export function useThemeColors() {
  const [themeColors] = Settings.useGlobalSettings(ColorTheme);
  const invoke = () => ipcRenderer.invoke('theme-color:which-system');
  const { result } : { result: 'dark' | 'light' } = usePromise(invoke());
  if (themeColors === 'system')
    return result === 'dark' ? 'dark-code' : 'default';
  return themeColors === 'dark' ? 'dark-code' : 'default';
}

export function useThemeButtons(props: ThemeProps): ThemeControls {
  const [fontSize, setFontSize] = Settings.useGlobalSettings(props.fontSize);
  const [wrapText, setWrapText] = Settings.useGlobalSettings(props.wrapText);
  const zoomIn = () => fontSize < 48 && setFontSize(fontSize + 2);
  const zoomOut = () => fontSize > 4 && setFontSize(fontSize - 2);
  const flipWrapText = () => setWrapText(!wrapText);
  const { disabled = false } = props;
  return {
    theme: useThemeColors(),
    fontSize,
    wrapText,
    buttons: [
      <IconButton
        key="zoom.out"
        icon="ZOOM.OUT"
        onClick={zoomOut}
        disabled={disabled}
        title="Decrease font size"
      />,
      <IconButton
        key="zoom.in"
        icon="ZOOM.IN"
        onClick={zoomIn}
        disabled={disabled}
        title="Increase font size"
      />,
      <IconButton
        key="wrap"
        icon="WRAPTEXT"
        selected={wrapText}
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
