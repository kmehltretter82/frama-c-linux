// --------------------------------------------------------------------------
// --- Electron main-process entry-point for Dome.
// --------------------------------------------------------------------------

/*
   Template of ./src/main/index.js
   Imported from $(DOME)/template/main.js

   The call to Dome.start() will initialize the Dome application
   and create the main window that will run the renderer process
   from `src/renderer/index.js`.

   You may add your own code to be run in the Electron main-process
   before or after the call to `Dome.start()`.
*/

import * as Dome from 'dome' ;
Dome.setName('Ivette');
Dome.start();
