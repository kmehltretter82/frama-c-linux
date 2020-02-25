// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import States from 'frama-c/states' ;
import { ArrayModel } from 'dome/table/arrays' ;
import { Table, Column, DefineColumn } from 'dome/table/views' ;

// --------------------------------------------------------------------------
// --- Properties Array
// --------------------------------------------------------------------------

const PropTable = () => {
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

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default { PropTable };

// --------------------------------------------------------------------------
