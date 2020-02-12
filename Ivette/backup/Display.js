// --------------------------------------------------------------------------
// --- Module Control View
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import { Catch } from 'dome/errors' ;
import { Label } from 'dome/controls/labels' ;
import Toolbar from 'dome/layout/toolbars' ;
import Dispatch from 'dome/layout/dispatch' ;
import Project from './Project' ;
import { ProvideModule } from '@ivette' ;

// --------------------------------------------------------------------------
// --- Current Module Display
// --------------------------------------------------------------------------

export default function Display()
{
  const [ { current } ] = Project.useState();
  if (!current)
    return <Label>No module selected.</Label> ;
  else
    return (
      <ProvideModule module={current}>
        <Catch label='Plugin Main View'>
          <Dome.Render>{current.renderMain}</Dome.Render>
        </Catch>
      </ProvideModule>
    );
}

// --------------------------------------------------------------------------
