// --------------------------------------------------------------------------
// --- Webpack extension for electron main-process
// --------------------------------------------------------------------------

/*
   Template from $(DOME)/template/webpack.main.js

   This webpack definitions will be merged into electron-webpack
   ones thanks to electron-webpack.json configuration file.

   You may extend it with your own additions.
*/

const path = require('path');
const DOME = process.env.DOME || path.resolve( __dirname , 'dome' );

module.exports = {
  module: {
    rules: [
      { test: /\.css$/, use: [ 'css-loader' ] }
    ],
    strictExportPresence: true
  },
  resolve: {
    alias: {
      '@plugins':     path.resolve( __dirname , 'src/plugins' ),
      'dome/misc':    path.resolve( DOME , 'src/misc' ),
      'dome/system':  path.resolve( DOME , 'src/misc/system.js' ),
      'dome$':        path.resolve( DOME , 'src/renderer/dome.tsx' ),
      'dome':         path.resolve( DOME , 'src/renderer' ),
      'react-dom':    '@hot-loader/react-dom'
    }
  }
} ;

// --------------------------------------------------------------------------
