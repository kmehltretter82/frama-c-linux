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

// --------------------------------------------------------------------------

module.exports = {
  module: {
    rules: [
      { test: /\.css$/, use: [ 'css-loader' ] },
      { test: /\.(ts|js)x?$/, use: [ 'babel-loader' ], exclude: /node_modules/ }
    ],
    strictExportPresence: true
  },
  resolve: {
    extensions: ['.ts', '.tsx', '.js', 'jsx', '.json'],
    alias: {
      'frama-c/api':  path.resolve( __dirname , 'api/generated' ),
      'frama-c':      path.resolve( __dirname , 'src/frama-c' ),
      'ivette':       path.resolve( __dirname , 'src/renderer/LabView' ),
      'dome/misc':    path.resolve( DOME , 'misc' ),
      'dome/system':  path.resolve( DOME , 'misc/system.ts' ),
      'dome$':        path.resolve( DOME , 'renderer/dome.tsx' ),
      'dome':         path.resolve( DOME , 'renderer' ),
      'react-dom':    '@hot-loader/react-dom'
    }
  }
} ;

// --------------------------------------------------------------------------
