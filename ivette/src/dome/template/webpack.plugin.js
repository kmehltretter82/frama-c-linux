// --------------------------------------------------------------------------
// --- Webpack configuration for packing plugins
// --------------------------------------------------------------------------

/*
   Template of ./webpack.plugin.js from $(DOME)/template/webpack.plugin.js

   This webpack definitions will be used to make plugin bundles.

   You may extend it with your own additions.
*/

const path = require('path');
const DOME = process.env.DOME || path.resolve( __dirname , 'dome' );
const PLUGIN = process.env.DOME_PLUGIN ;
const ENTRY = path.resolve( __dirname , 'src/plugins' , PLUGIN );
const DIST = path.resolve( __dirname , 'dist/plugins' , PLUGIN );

module.exports = {
  entry: ENTRY,
  output: {
    path: DIST,
    filename: 'bundle.js',
    libraryTarget: 'commonjs2'
  },
  module: {
    rules: [
      { test: /\.css$/, use: [ 'style-loader', 'css-loader' ] },
      { test: /\.js$/, use: [ 'babel-loader' ], exclude: /(node_modules)/ }
    ]
  },
  externals: [
    'lodash',
    'react',
    /^dome\/.+$/,
    /^@plugins\/.+$/,
    /^@\/.+$/
  ]
};

// --------------------------------------------------------------------------
