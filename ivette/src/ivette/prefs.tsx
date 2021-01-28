// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module ivette/prefs
 */

import React from 'react';

import { popupMenu } from 'dome';
import * as Settings from 'dome/data/settings';
import { IconButton } from 'dome/controls/buttons';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

export const THEMES = [
  { id: 'default', label: 'Default' },
  { id: 'ambiance', label: 'Ambiance' },
  { id: 'solarized light', label: 'Solarized Light' },
  { id: 'solarized dark', label: 'Solarized Dark' },
];

// --------------------------------------------------------------------------
// --- AST View Preferences
// --------------------------------------------------------------------------

export const AstTheme = new Settings.GString('ASTview.theme', 'default');
export const AstFontSize = new Settings.GNumber('ASTview.fontSize', 12);
export const AstWrapText = new Settings.GFalse('ASTview.wrapText');

export const SourceTheme = new Settings.GString('SourceCode.theme', 'default');
export const SourceFontSize = new Settings.GNumber('SourceCode.fontSize', 12);
export const SourceWrapText = new Settings.GFalse('SourceCode.wrapText');

export interface ThemeProps {
  target: string;
  theme: Settings.GlobalSettings<string>;
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

export function useThemeButtons(props: ThemeProps): ThemeControls {
  const [theme, setTheme] = Settings.useGlobalSettings(props.theme);
  const [fontSize, setFontSize] = Settings.useGlobalSettings(props.fontSize);
  const [wrapText, setWrapText] = Settings.useGlobalSettings(props.wrapText);
  const zoomIn = () => fontSize < 48 && setFontSize(fontSize + 2);
  const zoomOut = () => fontSize > 4 && setFontSize(fontSize - 2);
  const flipWrapText = () => setWrapText(!wrapText);
  const selectTheme = (id?: string) => id && setTheme(id);
  const themeItem = (th: { id: string; label: string }) => (
    { checked: th.id === theme, ...th }
  );
  const themePopup = () => popupMenu(THEMES.map(themeItem), selectTheme);
  const { disabled = false } = props;
  return {
    theme,
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
        key="theme"
        icon="PAINTBRUSH"
        onClick={themePopup}
        title="Choose theme"
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
