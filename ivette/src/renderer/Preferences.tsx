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

/* eslint-disable @typescript-eslint/explicit-function-return-type */

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
import * as P from 'ivette/prefs';

// --------------------------------------------------------------------------
// --- Font Forms
// --------------------------------------------------------------------------

function ThemeFields(props: P.ThemeProps) {
  const theme = Forms.useDefined(Forms.useValid(
    Settings.useGlobalSettings(props.theme),
  ));
  const fontsize = Forms.useValid(
    Settings.useGlobalSettings(props.fontSize),
  );
  const wraptext = Forms.useValid(
    Settings.useGlobalSettings(props.wrapText),
  );
  const options = P.THEMES.map(({ id, label }) => (
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
// --- Editor Command Forms
// --------------------------------------------------------------------------
function EditorCommandFields(props: P.EditorCommandProps) {
  const cmd = Forms.useDefined(Forms.useValid(
    Settings.useGlobalSettings(props.command),
  ));
  const title =
    'Command to open an external editor on Ctrl-click in the source code view.'
    + '\nUse %s for the file name, %n for the line number'
    + ' and %c for the selected character.';
  return (<Forms.TextCodeField state={cmd} label="Command" title={title} />);
}

// --------------------------------------------------------------------------
// --- Export Components
// --------------------------------------------------------------------------

export default function Preferences() {
  return (
    <Forms.Page>
      <Forms.Section label="AST View" unfold>
        <ThemeFields
          target="Internal AST"
          theme={P.AstTheme}
          fontSize={P.AstFontSize}
          wrapText={P.AstWrapText}
        />
      </Forms.Section>
      <Forms.Section label="Source View" unfold>
        <ThemeFields
          target="Source Code"
          theme={P.SourceTheme}
          fontSize={P.SourceFontSize}
          wrapText={P.SourceWrapText}
        />
      </Forms.Section>
      <Forms.Section label="Editor Command" unfold>
        <EditorCommandFields command={P.EditorCommand} />
      </Forms.Section>
    </Forms.Page>
  )
}

// --------------------------------------------------------------------------
