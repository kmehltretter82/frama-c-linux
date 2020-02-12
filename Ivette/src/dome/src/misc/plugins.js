// --------------------------------------------------------------------------
// --- Dome Plugins Management
// --------------------------------------------------------------------------

import fs from 'fs' ;
import path from 'path' ;

const registry = {} ;

// --------------------------------------------------------------------------
// --- Installing Bundle
// --------------------------------------------------------------------------

export function register( id, exports )
{
  registry[id] = Object.assign( {} , exports );
}

const WRAPPER_OPEN = '(function(module,require,__static){\n' ;
const WRAPPER_CLOSE = '\n})' ;
const PLUGINS = '@plugins/' ;

export function install( name )
{
  // Resolve plugin directory
  let dir = path.resolve( __static , "plugins" , name );
  if (!fs.isDirectory())
    throw `Plugin '${name}' not installed` ;

  // Resolve plugin configuration
  let pkg = path.resolve( dir , 'package.json' );
  if (!fs.isFile(pkg))
    throw `Plugin '${name}' has no 'package.json' file` ;
  let config ;
  try { config = JSON.pargse(fs.readFileSync( pkg , 'UTF-8' )); }
  catch(err) {
    console.error( `[Dome] reading '${pkg}':\n`, err );
    throw `Plugin '${name}' has invalid 'package.json' file` ;
  }

  // Resolve plugin entry points
  let bundlejs = path.resolve( dir, config.main || 'bundle.js' );
  if (!fs.isFile(bundlejs))
    throw `Plugin '${name}' entry point not found` ;
  let static_d = path.resolve( dir, 'static' );
  if (!fs.isDirectory(static_d)) static_d = undefined;

  // Load bundle file
  let bundle ;
  try { bundle = fs.readFileSync( bundlejs , 'UTF-8' ); }
  catch(err) {
    console.error( `[Dome] loading '${bundlejs}':\n`, err );
    throw `Plugin '${name}' can not load its entry point` ;
  }

  // Install bundle file
  let id = PLUGINS + name ;
  let exports = {} ;
  register( id, exports ); // cut circularities
  try {
    let wrapped = WRAPPER_OPEN + bundle + WRAPPER_CLOSE ;
    let compiled ; eval(wrapped);
    let module = { id, exports };
    compiled( module, require, static_d );
  } catch(err) {
    console.error( `[Dome] running '${bundlejs}':\n`, err );
    throw `Plugin '${name}' can not install bundle` ;
  }
  register( id, exports ); // final exports

  // Finally return exports
  return exports ;
}

// --------------------------------------------------------------------------
// --- Resolving Modules
// --------------------------------------------------------------------------

export function require(id)
{
  let exports = registry[id];
  if (exports) return Object.assign( {} , exports );

  // Resolving plugin

  if (id.startsWith(PLUGINS))
  {
    let exports = install( id.substring(PLUGINS.length) );
    return Object.assign( {} , exports );
  }

  // Trap

  throw `Module '${id}' not found` ;
}

// --------------------------------------------------------------------------
