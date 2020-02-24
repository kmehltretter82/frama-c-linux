// --------------------------------------------------------------------------
// --- Properties
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import States from 'frama-c/states' ;
import { ArrayModel } from 'dome/table/arrays' ;

// --------------------------------------------------------------------------
// --- Properties Array
// --------------------------------------------------------------------------

const Table = () => {
  const model = React.useMemo( () => new ArrayModel() );
  const items = States.useSyncArray('kernel.properties');
  if (items)
    return (
      <ul>
        {items.map((item) => (<li key={item.id}><tt>{item.id}</tt></li>))}
      </ul>
    );
  else
    return "Empty" ;
};

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default { Table };

// --------------------------------------------------------------------------
