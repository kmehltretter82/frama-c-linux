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

import * as Settings from 'dome/data/settings';
import * as Forms from 'dome/layout/forms';

export const THEMES = [
  { id: 'default', label: 'Default' },
  { id: 'ambiance', label: 'Ambiance' },
  { id: 'solarized light', label: 'Solarized Light' },
  { id: 'solarized dark', label: 'Solarized Dark' },
];

// --------------------------------------------------------------------------
// --- AST View Preferences
// --------------------------------------------------------------------------

export const ThemeASTview = new Settings.GString('ASTview.theme', 'default');
export const FontSizeASTview = new Settings.GNumber('ASTview.fontSize', 12);

const ASTviewPrefs = () => {

  const theme = Forms.useDefined(Forms.useValid(
    Settings.useGlobalSettings(ThemeASTview),
  ));
  const font = Forms.useValid(
    Settings.useGlobalSettings(FontSizeASTview),
  );

  return (
    <Forms.Page>
      <Forms.Section label="AST View" unfold>
        <Forms.SelectField
          state={theme}
          label="Theme"
          title="Set the color theme of the AST source code"
        >
          <option value="default" label="Default" />
          <option value="ambiance" label="Ambiance" />
          <option value="solarized light" label="Solarized light" />
          <option value="solarized dark" label="Solarized dark" />
        </Forms.SelectField>
        <Forms.SliderField
          state={font}
          label="Font Size"
          title="Set the font size of the AST source code"
          min={8}
          max={32}
          step={2}
        />
      </Forms.Section>
    </Forms.Page>
  );
};

// --------------------------------------------------------------------------
// --- Source Code Preferences
// --------------------------------------------------------------------------

export const ThemeSC = new Settings.GString('SourceCode.theme', 'default');
export const FontSizeSC = new Settings.GNumber('SourceCode.fontSize', 12);

const SourceCodePrefs = () => {

  const theme = Forms.useDefined(Forms.useValid(
    Settings.useGlobalSettings(ThemeSC),
  ));
  const font = Forms.useValid(
    Settings.useGlobalSettings(FontSizeSC),
  );

  return (
    <Forms.Page>
      <Forms.Section label="Source Code" unfold>
        <Forms.SelectField
          state={theme}
          label="Theme"
          title="Set the color theme of the source code"
        >
          <option value="default" label="Default" />
          <option value="ambiance" label="Ambiance" />
          <option value="solarized light" label="Solarized light" />
          <option value="solarized dark" label="Solarized dark" />
        </Forms.SelectField>
        <Forms.SliderField
          state={font}
          label="Font Size"
          title="Set the font size of the source code"
          min={8}
          max={32}
          step={2}
        />
      </Forms.Section>
    </Forms.Page>
  );
};

// --------------------------------------------------------------------------
// --- Export Components
// --------------------------------------------------------------------------

export default (() => (
  <>
    <ASTviewPrefs />
    <SourceCodePrefs />
  </>
));
