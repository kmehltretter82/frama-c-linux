// --------------------------------------------------------------------------
// --- Frama-C Source Panel
// -------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;

import { Button } from 'dome/controls/buttons';
import Toolbar from 'dome/layout/toolbars' ;
import { Hbox, Hfill, Vbox, Vfill, Space } from 'dome/layout/boxes' ;
import { Splitter } from 'dome/layout/splitters' ;
import { Column, Table } from 'dome/table/views' ;
import { Text } from 'dome/text/editors' ;
import Server from './server.js' ;
import Events from './Events.js' ;

import { useState, useEffect } from 'react' ;

import 'codemirror/mode/clike/clike.js';
import 'codemirror/theme/ambiance.css' ;
import 'codemirror/theme/solarized.css';

/* Pretty prints the source code from [text] in [buffer]. */
function printSource (buffer, text) {
  if (text === null) return;
  if (Array.isArray(text)) {
    const tag = text.shift();
    if (tag !== '') {
      buffer.openTextMarker( { id:tag } );
      text.forEach(txt => printSource(buffer, txt));
      buffer.closeTextMarker();
    } else
      text.forEach(txt => printSource(buffer, txt));
  } else
    buffer.append(text);
}

/* Display the list of functions and the source code for the selected function
   in the list. */
export default function Source (props) {
  /* Buffer for the source code. */
  const buffer = props.sourceCode;
  /* Model for the function list. */
  const model = props.functions;

  /* Print the source code of the function [data.fct]. */
  function printFunction (data) {
    console.log("Select function: " + data.fct);
    Server.sendGET("kernel.ast.printFunction", data.fct, false).then
    ( data => {
      buffer.clear();
      printSource(buffer, data);
    });
  }

  const [ theme, setTheme ] = useState('default');
  function selectTheme (name) {
    return function () { setTheme(name); }
  }

  function contextMenu (data) {
    const item1 = { label:"Default", onClick:selectTheme("default") };
    const item2 = { label:"Ambiance", onClick:selectTheme("ambiance") };
    const item3 = { label:"Solarized light", onClick:selectTheme("solarized light") };
    const item4 = { label:"Solarized dark", onClick:selectTheme("solarized dark") };
    Dome.popupMenu([item1, item2, item3, item4]).catch(() => {});
  }

  /* Table for the function list. */
  const table =
    <Table model={model}
           onSelection={printFunction} >
      <Column id='fct'
              label='Functions'
              title='List of functions in the current Frama-C project' />
    </Table>;

  const [ lineWrapping, setLineWrapping ] = useState(false);
  function changeLineWrapping () { setLineWrapping(!lineWrapping); }

  const code = <Text buffer={buffer}
                     mode='text/x-csrc'
                     theme={theme}
                     lineWrapping={lineWrapping}
                     readOnly />;

  const [ fontSize, setFontSize ] = useState(12);
  function increaseFontSize () { setFontSize(fontSize + 2); }
  function decreaseFontSize () { setFontSize(fontSize - 2); }

  const toolbar =
    <Toolbar.ToolBar>
      <Toolbar.Space/>
      <Toolbar.Select
        value={theme}
        onChange={(name) => {selectTheme(name)();}} >
        <option value='default' label='Default'/>
        <option value='ambiance' label='Ambiance'/>
        <option value='solarized light' label='Solarized light'/>
        <option value='solarized dark' label='Solarized dark'/>
      </Toolbar.Select>
      <Toolbar.ButtonGroup>
        <Toolbar.Button
          icon='MINUS'
          title='Decrease the font size'
          onClick={decreaseFontSize}
        />
        <Toolbar.Button
          icon='PLUS'
          title='Increase the font size'
          onClick={increaseFontSize}
        />
      </Toolbar.ButtonGroup>
      <Toolbar.Button icon={lineWrapping ? "CHECK" : "CROSS"}
                      label="Line wrapping"
                      title="Change line wrapping mode"
                      onClick={changeLineWrapping} />
    </Toolbar.ToolBar>;

  return (
    <Splitter dir='LEFT' >
      <Vfill style={{ minWidth: 100 }}> {table} </Vfill>
      <Vfill onContextMenu={contextMenu} style={{ fontSize: fontSize }} >
        {toolbar}
        {code}
      </Vfill>
    </Splitter>
  );
}
