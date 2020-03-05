// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import States from 'frama-c/states' ;
import { Label, Code } from 'dome/controls/labels' ;
import { ArrayModel } from 'dome/table/arrays' ;
import { Table, Column, DefineColumn } from 'dome/table/views' ;
import { Component } from 'frama-c/labviews' ;

// --------------------------------------------------------------------------
// --- Properties Array
// --------------------------------------------------------------------------

const ColumnCode = DefineColumn({ renderValue: (text) => <Code>{text}</Code> });
const ColumnTag = DefineColumn({ renderValue: ({ label, descr }) => (
  <Label label={label} title={descr}/>
)});

// --------------------------------------------------------------------------
// --- Columns
// -------------------------------------------------------------------------

const RenderTable = () => {
  const model = React.useMemo( () => new ArrayModel() , [] );
  const items = States.useSyncArray('kernel.properties');
  const status = States.useDictionary('kernel.dictionary.propstatus');
  const getStatus = ({status:st}) => status[st] || { label:st } ;
  model.setData( _.toArray( items ) );
  return (
    <Table model={model}>
      <ColumnCode id='function' label='Function' width={120} />
      <ColumnCode id='descr' label='Description' fill />
      <ColumnTag id='status' label='Status' fixed width={80} align='center' getValue={getStatus} />
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
