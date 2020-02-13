/** @module @ivette */

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import System from 'dome/system' ;
import { Module, Factory, CONFIG, UPDATE } from './plugins' ;
import { Registry } from './stores' ;

// --------------------------------------------------------------------------
// --- Plugin & Module Registries
// --------------------------------------------------------------------------

const pluginsRegistry = new Registry('plugin');
const modulesRegistry = new Registry('module');

/**
   @method
   @summary Registered Plugins.
   @return {Class[]} an array of `Plugin` classes
 */
export const getPlugins = () => pluginsRegistry.elements() ;

/**
   @method
   @summary Registered Modules.
   @return {Plugin[]} an array of `Plugin` instances
 */
export const getModules = () => modulesRegistry.elements() ;

/**
   @method
   @summary Returns a module by id.
 */
export const getModule = (id) => modulesRegistry.get(id);

// --------------------------------------------------------------------------
// --- Register Plugin
// --------------------------------------------------------------------------

const checkModule = ( m ) => {
  if (!(m instanceof Module))
    throw `Invalid Plugin '${m}'` ;
};

const checkPlugin = ( P ) => checkModule( P.prototype );
const getPluginId = ( m ) => m.constructor.id ;

/**
   @summary Register a (new) plugin.
   @param {PLUGIN|Class<Module>} Plugin -
   [plugin specification](module-@ivette_plugins.html#~PLUGIN) or
   [module class](module-@ivette_plugins.html#Module)
   @description

   Register a new plugin in the Ivette system.

   It is recommand to use a [PLUGIN](module-@ivette_plugins.html#~PLUGIN)
   object for plugin specification.
   If a class is provided, it shall extends the [Module](module-@ivette_plugins.html#Module)
   base class and shall have static properties `id`, `label`
   and `title` defined.

   Unless your are in development mode (which implies hot module reloading),
   it is not permitted to register two plugins with the same identifier,
   and an error would be emitted on the console in turn.
 */
function registerPlugin( spec )
{
  const ThePlugin = typeof(spec)==='object' ? Factory(spec) : spec ;
  checkPlugin( ThePlugin );
  const id = ThePlugin.id ;
  if (!id)
    throw `Invalid plugin: missing identifier` ;
  if (!System.DEVEL && pluginsRegistry.get(id))
    throw `Duplicate plugin '${id}'` ;
  pluginsRegistry.add( ThePlugin );
  if (System.DEVEL) modulesRegistry.forEach( (module) => {
    // Propagates changes from HMR
    if (module.constructor.id === ThePlugin.id) Object.setPrototypeOf( module , ThePlugin.prototype );
  });
}

// --------------------------------------------------------------------------
// --- Project Directory
// --------------------------------------------------------------------------

let projectDirectory ;

const getProjectDir = () => {
  if (!projectDirectory) return projectDirectory;
  let cwd = System.getWorkingDir();
  return cwd ? System.join( cwd , '.ivette' ) : undefined ;
};
const getProjectIndex = () => System.join( getProjectDir(), 'index.json' );
const getModuleSession = (mid) => System.join( getProjectDir(), 'modules', mid );
const getModuleConfig = (mid) => System.join( getProjectDir() , 'config.json' );

/** @method
    @summary Check is fome module is locked.
    @return {boolean} */
export const isProjectLocked = () => (
  modulesRegistry.find((m) => m.locked()) !== undefined
);

/**
   @method
   @summary Returns current project directory.
   @return {string} absolute path or undefined */
export const getProjectDirectory = () => projectDirectory;

/**
    @summary Find enclosing project.
    @param {string} path - a file path to starts with
    @return {string} project directory holding that path
    @description
    Looks for the closest directory with name `"*.ivette"`
    containing the given path, or the closest directory with a `.ivette`
    file at root.
    Returns `undefined` if not found.
*/
export function lookupProject( path ) {
  try {
    path = System.resolve(path);
    let prev ;
    while( prev !== path )
    {
      if (System.extname(path) === '.ivette' && System.isDirectory(path))
        return path;
      let here = System.join( path, '.ivette' );
      if (System.isDirectory(here))
        return here;
      prev = path ;
      path = System.dirname(path);
    }
  } catch(_err) { }
  return undefined ;
}

// --------------------------------------------------------------------------
// --- Project Index
// --------------------------------------------------------------------------

const saveIndex = async () => {
  let modules = modulesRegistry.elements().map((m) => m.id);
  let indexFile = getProjectIndex();
  let indexJSON = JSON.stringify({ modules });
  await System.mkDir( projectDirectory , { recursive: true });
  await System.writeFile( indexFile , indexJSON );
};

const loadIndex = () => {
  let indexFile = getProjectIndex();
  if (System.isFile(indexFile)) {
    return System.readFile( indexFile ).then((content) => {
      try {
        return JSON.parse(content);
      } catch(err) {
        console.warn('[Ivette] invalid index.json:',err);
        return {};
      }
    });
  } else {
    return Promise.resolve({});
  }
};

// --------------------------------------------------------------------------
// --- Module Helpers
// --------------------------------------------------------------------------

export const isFresh = (id) => modulesRegistry.isFresh(id);
export const isValid = (id) => modulesRegistry.isValid(id);

/**
   @summary Creates a fresh Plugin instance.
   @param {Class} Plugin - a class extending Plugin
   @return {Plugin} a fresh module instance
   @description
   The returned module has a fresh identifier but is not yet registered.
 */
export function newModule( Plugin )
{
  checkPlugin( Plugin );
  let module = new Plugin();
  module.id = modulesRegistry.fresh( Plugin.id );
  return module;
}

/**
   @summary Creates a fresh duplicate of a Plugin instance.
   @param {Module} module - the instance to duplicate
   @return {Module} a fresh module instance
   @description
   The returned module has a fresh identifier but is not yet registered.
   It inherits from the original `module` configuration, with tagged label and title.
 */
export function duplicateModule( module )
{
  let { label, title, constructor: Plugin } = module ;
  checkPlugin( Plugin );
  let duplicate = new Plugin();
  duplicate.id = modulesRegistry.fresh( module.id );
  duplicate.label = label && label + " (copy)" ;
  duplicate.title = title && title + " (duplicated)" ;
  duplicate.config = _.cloneDeep(module.config);
  return duplicate ;
}

/**
   @summary Unregister a module (if registered).
   @param {Module} module - the module to remove
   @return {Promise} resolved when the module has been removed (from disk)
   @description

   Remove a module from the current project.
   If the module is locked, an exception if raised.
   The function does nothing if the module is not registered.
   The promise is resolved when the module session directory has been fully removed.
 */
function removeModule( module )
{
  checkModule( module );
  if (module.locked()) throw `Try to remove locked module '${module}'` ;
  modulesRegistry.remove( module.id );
  if (module.session)
    return System.rmDir( module.session, { recursive: true } ).then(saveIndex);
  else
    return saveIndex();
}

// --------------------------------------------------------------------------
// --- Commit Module
// --------------------------------------------------------------------------

/**
   @summary Commit module updates.
   @param {Module} module - the module to update
   @param {object} update - the module fields to update with
   @param {string} [update.id] - new identifier
   @param {string} [update.label] - new display name
   @param {string} [update.title] - new short description
   @param {object} [update.config] - new configuration
   @return {Promise} resolved when the module has been commited (on disk)
   @description

   The module is registered in the current project, or updated if already present.
   Its session directory is created or renamed if necessary.
   Finally, the module is emitted a `Plugin.CONFIG` event.

 */
export function commitModule( module, { id, label, title, config } )
{
  checkModule( module );
  if (module.locked()) throw `Try to commit locked module '${id}'` ;

  const oldId = module.id ;
  const newId = id || oldId ;

  // Update registry
  let index ; // Promise
  if ( newId !== oldId ) {
    module.id = newId ;
    modulesRegistry.remove( oldId );
    modulesRegistry.add( module );
    index = saveIndex();
  } else {
    if (!modulesRegistry.get( newId )) {
      modulesRegistry.add( module );
      index = saveIndex();
    }
  }

  // Update module
  if (label !== undefined) module.label = label;
  if (title !== undefined) module.title = title;
  if (config !== undefined) module.config = config ;

  // Setup session directory
  let setup ; // Promise
  let oldSession = module.session ;
  let newSession = System.join( projectDirectory, 'modules', newId );
  if ( newSession !== oldSession ) {
    module.session = newSession ;
    if (System.exists( oldSession ))
      setup = System.rename( oldSession, newSession );
    else
      setup = System.mkDir( newSession, { recursive:true } );
  } else {
    if (!System.exists( newSession ))
      setup = System.mkDir( newSession , { recursive:true } );
    else
      setup = Promise.resolve();
  }

  // Backup config
  let configFile = System.join( module.session , 'config.json' );
  if (!id || !label || !title || !config || !System.exists(configFile))
  {
    let plugin = getPluginId( module );
    let configJSON = JSON.stringify({ id, label, title, plugin, config });
    setup.then(() => System.writeFile( configFile , configJSON ));
  }

  // Batch updates and finally emit config event
  return Promise.all([index,setup]).finally(() => module.emit( CONFIG ));
}

// --------------------------------------------------------------------------
// --- Project Management
// --------------------------------------------------------------------------

function loadProjectModule(id)
{
  if (modulesRegistry.get(id))
    return Promise.reject('Duplicate module');
  let session = System.join( projectDirectory, 'modules', id );
  let configFile = System.join( session , 'config.json' );
  return System.readFile( configFile )
    .then( (configJSON) => {
      let moduleConfig = JSON.parse(configJSON);
      let { label, title, plugin, config } = moduleConfig ;
      let P = pluginsRegistry.get( plugin );
      if (!P) throw `Invalid plugin identifier ('${plugin}')` ;
      let module = new P();
      module.id = id ;
      module.label = label ;
      module.title = title ;
      module.config = config ;
      modulesRegistry.add( module );
      module.emit( CONFIG );
    });
}

function reportLoadModule(id) {
  return loadProjectModule(id)
    .then(() => undefined)
    .catch((err) => `Error with module ${id}: ${err}`);
}

/** Change project directory.
    @param {string} path - the directory of the project
    @return {Promise} returning an array of errors
*/
export function loadProject( path ) {
  if (isProjectLocked()) throw 'Try to close locked project' ;
  if (!path) throw 'Try to open empty project' ;
  projectDirectory = path ;
  modulesRegistry.clear();
  return loadIndex()
    .then(({ modules=[] }) => Promise.all(modules.map(reportLoadModule)))
    .then((errors) => errors.filter((e) => e !== undefined));
}

// --------------------------------------------------------------------------
// --- Plugin Hooks
// --------------------------------------------------------------------------

const ModuleContext = React.createContext();

/**
   @class
   @summary Set the current module for children components.
   @property {Module} module - the current module (can be `'undefined'`)
   @property {React.Children} children - content to be rendered with the current module
 */
export const ProvideModule = ({ module, children }) => (
  <ModuleContext.Provider value={module}>
    {children}
  </ModuleContext.Provider>
);

/**
   @method
   @summary Use the current module (Custom React Hook).
   @return {Module} the current module
   @description
   Convenient method to obtain the current module. Does _not_ update on events.
*/
export const useModule = () => React.useContext(ModuleContext);

/**
   @method
   @summary Listen to (current) module event (Custom React Hook).
   @parameter {string} event - the plugin event to listen on
   @parameter {function} callback - the callback on event
   @return {Plugin} the plugin instance of the current module
   @description
   Same as `Dome.useEmitter(module,event,callback)` with the current module.
   The hook itself does not force update, unless the callback does.
*/
export const useEvent = (event,callback) => {
  let module = React.useContext(ModuleContext);
  Dome.useEmitter( module, event, callback );
};

/**
   @method
   @summary Use the current module with optional update on events (Custom React Hook).
   @parameter {string} [events...] - the event(s) to listen on, in addition to `UPDATE`
   @return {Module} the current module
   @description
   Convenient method to obtain the current module and connect to updating events.
*/
export const useUpdate = (...events) => {
  let module = React.useContext(ModuleContext);
  let callback = Dome.useForceUpdate();
  React.useEffect(() => {
    if (module) {
      events.push(UPDATE);
      events.forEach((evt) => module.on(evt,callback));
      return () => events.forEach((evt) => module.off(evt,callback));
    } else
      return undefined;
  });
  return module ;
};

/**
   @method
   @summary Returns the current module configuration (Custom React Hook).
   @return {Module} the plugin configuration (up-to-date)
   @description
   Equivalent to `useUpdate(CONFIG).config` unless there is no current module.
*/
export const useConfig = () => {
  let m = useUpdate(CONFIG);
  return m && m.config;
};

// --------------------------------------------------------------------------
// --- Export Default
// --------------------------------------------------------------------------

export default {
  registerPlugin,
  getPlugins,
  getModules,
  isProjectLocked,
  getProjectDirectory,
  loadProject,
  lookupProject,
  isFresh, isValid,
  newModule,
  duplicateModule,
  commitModule,
  removeModule,
  ProvideModule,
  useModule,
  useEvent,
  useUpdate,
  useConfig
};

// --------------------------------------------------------------------------
