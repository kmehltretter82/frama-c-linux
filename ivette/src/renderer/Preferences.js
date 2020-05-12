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

  function useGlobal (param) {
    return Dome.useGlobalSetting('ASTview.' + param);
  }

  const [theme, setTheme] = useGlobal('theme');
  const [lineWrapping, setLineWrapping] = useGlobal('lineWrapping');
  const [fontSize, setFontSize] = useGlobal('fontSize');

  return (
    <>
      <Form>
        <Section label="AST View" unfold={true}>
        <FieldSelect
          value={theme}
          onChange={(name) => setTheme(name)}
          label="Theme: "
          title="Set the color theme of the AST source code">
          <option value='default' label='Default'/>
          <option value='ambiance' label='Ambiance'/>
          <option value='solarized light' label='Solarized light'/>
          <option value='solarized dark' label='Solarized dark'/>
        </FieldSelect>
        <FieldSlider
          value={fontSize}
          onChange={(n) => setFontSize(n)}
          label="Font size: "
          title="Set the font size of the AST source code"
          min={8}
          max={32}
          step={2}
        />
        <FieldCheckbox
          value={lineWrapping}
          onChange={(b) => setLineWrapping(b)}
          label="Line wrapping"
          title="Set the line wrapping mode of the AST source code"
        />
        </Section>
      </Form>
    </>
  );
}

export default (() => (
  <ASTviewPrefs/>
));
