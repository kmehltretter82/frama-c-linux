// --------------------------------------------------------------------------
// --- File Menu
// --------------------------------------------------------------------------

import fs from 'fs' ;
import path from 'path' ;
import Dome from 'dome' ;
import Dialogs from 'dome/dialogs' ;
import Project from './Project' ;
import Ivette from '@ivette' ;

// --------------------------------------------------------------------------
// --- Actions
// --------------------------------------------------------------------------

function openProject()
{
  console.log('OPEN PROJECT…');
}

// --------------------------------------------------------------------------
// --- Menu Items
// --------------------------------------------------------------------------

Dome.addMenuItem({
  menu: 'File',
  id: 'ivette.menu.file.open',
  label: 'Open Project…',
  onClick: openProject
});

Dome.onUpdate(() => {
  let enabled = Ivette.isProjectLocked();
  Dome.setMenuItem({ id: 'ivette.menu.file.open', enabled });
});

// --------------------------------------------------------------------------
