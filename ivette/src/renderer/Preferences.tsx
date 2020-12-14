// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

/*
   Template from $(DOME)/template/Settings.js

   This module shall export a React Component that
   will be rendered (with empty props and children)
   in the settings window of your application.

*/

import React from 'react';

import { popupMenu } from 'dome';
import * as Settings from 'dome/data/settings';
import * as Forms from 'dome/layout/forms';
import { IconButton } from 'dome/controls/buttons';

import 'codemirror/mode/clike/clike';
import 'codemirror/theme/ambiance.css';
import 'codemirror/theme/solarized.css';

const THEMES = [
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
// --- Font Forms
// --------------------------------------------------------------------------

function ThemeFields(props: ThemeProps) {
  const theme = Forms.useDefined(Forms.useValid(
    Settings.useGlobalSettings(props.theme),
  ));
  const fontsize = Forms.useValid(
    Settings.useGlobalSettings(props.fontSize),
  );
  const wraptext = Forms.useValid(
    Settings.useGlobalSettings(props.wrapText),
  );
  const options = THEMES.map(({ id, label }) => (
    <option key={id} value={id} label={label} />
  ));
  const { target } = props;
  return (
    <>
      <Forms.SelectField
        state={theme}
        label="Theme"
        title={`Set the color theme of ${target}`}
      >
        {options}
      </Forms.SelectField>
      <Forms.SliderField
        state={fontsize}
        label="Font Size"
        title={`Set the font size of ${target}`}
        min={8}
        max={32}
        step={2}
      />
      <Forms.CheckboxField
        state={wraptext}
        label="Wrap Text"
        title={`Set long line wrapping mode of ${target}`}
      />
    </>
  );
}

// --------------------------------------------------------------------------
// --- Export Components
// --------------------------------------------------------------------------

export default (() => (
  <Forms.Page>
    <Forms.Section label="AST View" unfold>
      <ThemeFields
        target="Internal AST"
        theme={AstTheme}
        fontSize={AstFontSize}
        wrapText={AstWrapText}
      />
    </Forms.Section>
    <Forms.Section label="Source View" unfold>
      <ThemeFields
        target="Source Code"
        theme={SourceTheme}
        fontSize={SourceFontSize}
        wrapText={SourceWrapText}
      />
    </Forms.Section>
  </Forms.Page>
));

// --------------------------------------------------------------------------
