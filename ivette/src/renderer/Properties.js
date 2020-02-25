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
  const model = React.useMemo( () => new ArrayModel() );
  const items = _.toArray( States.useSyncArray('kernel.properties') );
  console.log(items);
  if (items)
    return (
      <ul>
        {items.map((item) => (<li key={item.key}><tt>{item.key}</tt></li>))}
      </ul>
    );
  else
    return "Empty" ;
};

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default { PropTable };

// --------------------------------------------------------------------------
