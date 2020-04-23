// --------------------------------------------------------------------------
// --- Webpack extension for electron main-process
// --------------------------------------------------------------------------

/*
   Template of ./webpack.main.js from $(DOME)/template/webpack.main.js

   This webpack definitions will be merged into electron-webpack
   ones thanks to electron-webpack.json configuration file.

   You may extend it with your own additions.
*/

const path = require('path');
const DOME = process.env.DOME || path.resolve(__dirname , 'dome');
const ENV = process.env.DOME_ENV ;

// Do not use electron-devtools-installer in production mode
function domeDevtools() {
  switch(ENV) {
  case 'dev':
    return 'electron-devtools-installer';
  default:
    return path.resolve( DOME , 'src/misc/devtools.js' );
  }
}

module.exports = {
  resolve: {
    alias: {
      'dome$':         path.resolve( DOME , 'src/main/dome.js' ),
      'dome/system$':  path.resolve( DOME , 'src/misc/system.js' ),
      'dome/devtools': domeDevtools()
    }
  }
} ;

// --------------------------------------------------------------------------
