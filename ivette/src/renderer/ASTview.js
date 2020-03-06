// --------------------------------------------------------------------------
// --- AST Source Code
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import States from 'frama-c/states' ;
import { Component } from 'frama-c/labviews' ;

// --------------------------------------------------------------------------
// --- AST Printer
// --------------------------------------------------------------------------

const ASTview = () => {

  // Hooks
  const [ select, setSelect ] = States.useSelection();

  return (
    <div>
      <div>Function: {select && select.function}</div>
      <div>Marker: {select && select.marker}</div>
    </div>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component id='frama-c.astview'
             label='AST'
             title='Normalized source code representation.'
             >
    <ASTview/>
  </Component>
);

// --------------------------------------------------------------------------
