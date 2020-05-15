// --------------------------------------------------------------------------
// --- Main React Component rendered by './index.js'
// --------------------------------------------------------------------------

/*
   Template from $(DOME)/template/Settings.js

   This module shall export a React Component that
   will be rendered (with empty props and children)
   in the settings window of your application.

*/

import React from 'react' ;

import * as Dome from 'dome';
import { Form, Section, FieldSelect, FieldCheckbox, FieldSlider } from 'dome/layout/forms' ;

const ASTviewPrefs = () => {

  const [theme, setTheme] = Dome.useGlobalSetting('ASTview.theme', 'default');
  const [fontSize, setFontSize] = Dome.useGlobalSetting('ASTview.fontSize', 12);

  return (
    <React.Fragment>
      <Form>
        <Section label="AST View" unfold={true}>
          <FieldSelect
            value={theme}
            onChange={setTheme}
            label="Theme"
            title="Set the color theme of the AST source code">
            <option value='default' label='Default'/>
            <option value='ambiance' label='Ambiance'/>
            <option value='solarized light' label='Solarized light'/>
            <option value='solarized dark' label='Solarized dark'/>
          </FieldSelect>
          <FieldSlider
            value={fontSize}
            onChange={setFontSize}
            label="Font Size"
            title="Set the font size of the AST source code"
            min={8}
            max={32}
            step={2}
            />
        </Section>
      </Form>
    </React.Fragment>
  );
}

export default (() => (
  <ASTviewPrefs/>
));
