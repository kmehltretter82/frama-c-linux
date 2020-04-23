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
// --- Property Columns
// --------------------------------------------------------------------------

const ColumnCode = DefineColumn({ renderValue: (text) => <Code>{text}</Code> });
const ColumnTag = DefineColumn({ renderValue: ({ label, descr }) => (
  <Label label={label} title={descr}/>
)});

// --------------------------------------------------------------------------
// --- Properties Table
// -------------------------------------------------------------------------

const RenderTable = () => {

  // Hooks
  const model = React.useMemo( () => new ArrayModel() , [] );
  const items = States.useSyncArray('kernel.properties');
  const status = States.useDictionary('kernel.dictionary.propstatus');
  const [select,setSelect] = States.useSelection();
  React.useEffect( () => {
    model.setData( _.toArray( items ) );
  }, [ model, items ]);

  // Callbacks
  const getStatus = ({status:st}) => status[st] || { label:st } ;
  const selection = select ? items[ select.marker ] : undefined ;
  const onSelection = (item) => item && setSelect({
    marker: item.key,
    function: item.function
  });

  // Rendering
  return (
    <React.Fragment>
      <Table model={model}
             selection={selection}
             onSelection={onSelection}
             scrollToItem={selection}
             >
        <ColumnCode id='function' label='Function' width={120} />
        <ColumnCode id='descr' label='Description' fill />
        <ColumnTag id='status' label='Status'
                   fixed width={80} align='center'
                   getValue={getStatus} />
      </Table>
    </React.Fragment>
  );
};

// --------------------------------------------------------------------------
// --- Export Component
// -------------------------------------------------------------------------

export default () => (
  <Component id='frama-c.properties'
             label='Properties'
             title='Registered ACSL properties status' >
    <RenderTable/>
  </Component>
);

// --------------------------------------------------------------------------
