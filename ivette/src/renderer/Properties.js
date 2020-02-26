// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import States from 'frama-c/states' ;
import { Code } from 'dome/controls/labels' ;
import { ArrayModel } from 'dome/table/arrays' ;
import { Table, Column, DefineColumn } from 'dome/table/views' ;
import { Component } from 'frama-c/labviews' ;

// --------------------------------------------------------------------------
// --- Properties Array
// --------------------------------------------------------------------------

const ColumnCode = DefineColumn({ renderValue: (text) => <Code>{text}</Code> });

// --------------------------------------------------------------------------
// --- Columns
// -------------------------------------------------------------------------

const RenderTable = () => {
  const model = React.useMemo( () => new ArrayModel() , [] );
  const items = States.useSyncArray('kernel.properties');
  model.setData( _.toArray( items ) );
  return (
    <Table model={model}>
      <Column id='descr' label='Description' fill />
      <Column id='status' label='Status' align='center' />
    </Table>
  );
};

const PropTable = () => (
  <Component id='frama-c.properties'
             label='Properties'
             title='Registered Frama-C Property Status' >
    <RenderTable/>
  </Component>
);

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default { PropTable };

// --------------------------------------------------------------------------
