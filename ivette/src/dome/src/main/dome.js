/**
   @packageDocumentation
   @module dome(main)
   @description

   ## Dome Application (Main Process)

   This module manages the electron main-process of the application.
   Your application will launch on `Dome.start()`:

   @example
   // src/main/index.js:
   import * as Dome from 'dome' ;
   Dome.start();
*/

import _ from 'lodash' ;
import fs from 'fs' ;
import path from 'path' ;
import { app, ipcMain, BrowserWindow } from 'electron' ;
import installExtension , { REACT_DEVELOPER_TOOLS } from 'dome/devtools' ;
import * as Menubar from './menubar.js' ;
import SYS, * as System from 'dome/system' ;

// --------------------------------------------------------------------------
// --- System Helpers
// --------------------------------------------------------------------------

function fstat(path) {
  try {
    return fs.statSync(path);
  } catch(_error) {
    return undefined;
  }
}

// --------------------------------------------------------------------------
// --- Helpers
// --------------------------------------------------------------------------

const LOCAL = process.env.DOME_LOCAL ;

/** Development mode flag */
export const DEVEL = System.DEVEL ;

/** System platform */
export const platform = System.platform ;

// --------------------------------------------------------------------------
// --- Settings
// --------------------------------------------------------------------------

function loadSettings( file ) {
  try {
    if (!fstat(file))
      return {};
    const text = fs.readFileSync(file, { encoding: 'utf8' } );
    return Object.assign({}, JSON.parse(text));
  } catch(err) {
    console.error("[Dome] Unable to load settings", file, err);
    return {};
  }
}

function saveSettings( file, data={} ) {
  try {
    const text = JSON.stringify( data, undefined, DEVEL ? 2 : 0 );
    fs.writeFileSync( file, text, { encoding: 'utf8' }, (err) => { throw(err); } );
  } catch(err) {
    console.error("[Dome] Unable to save settings", file, err);
  }
}

// --------------------------------------------------------------------------
// --- Global Settings
// --------------------------------------------------------------------------

var GlobalSettings; // Current Dictionnary

const APP_DIR = app.getPath('userData');
const PATH_WINDOW_SETTINGS = path.join( APP_DIR, 'WindowSettings.json' );
const PATH_GLOBAL_SETTINGS = path.join( APP_DIR, 'GlobalSettings.json' );

function saveGlobalSettings() {
  try {
    if (!fstat( APP_DIR )) fs.mkdirSync( APP_DIR );
    saveSettings( PATH_GLOBAL_SETTINGS, GlobalSettings );
  } catch(err) {
    console.error("[Dome] Unable to save global settings", err);
  }
}

function obtainGlobalSettings() {
  if (!GlobalSettings) {
    GlobalSettings = loadSettings( PATH_GLOBAL_SETTINGS );
  }
  return GlobalSettings;
}

// --------------------------------------------------------------------------
// --- Window Settings & Frames
// --------------------------------------------------------------------------

/* Window Handle:
   {
     window: BrowserWindow ; // Also prevents Gc
     config: path;           // Path to config file
     frame: { x,y,w,h };     // Frame position
     settings: object;       // Current settings
     reload: boolean;        // Reloaded window
   }
 */

const WindowHandles = {}; // Indexed by *webContents* id

function saveWindowConfig(handle) {
  const settings = {
    frame: handle.frame,
    settings: handle.settings,
    devtools: handle.devtools
  };
  saveSettings( handle.config, settings );
}

function windowSyncSettings(event) {
  const handle = WindowHandles[event.sender.id];
  event.returnValue = {
    globals: obtainGlobalSettings(),
    settings: handle && handle.settings
  };
}

ipcMain.on('dome.ipc.settings.sync', windowSyncSettings );

// --------------------------------------------------------------------------
// --- Patching Settings
// --------------------------------------------------------------------------

function applyPatches( data, args ) {
  args.forEach(({ key, value }) => {
    if (value === null) {
      delete data[key];
    } else {
      data[key] = value;
    }
  });
}

function applyWindowSettings(event,args) {
  const handle = WindowHandles[event.sender.id];
  if (handle) {
    applyPatches( handle.settings, args );
    if (DEVEL) saveWindowConfig( handle );
  }
}

function applyGlobalSettings(event,args) {
  applyPatches( obtainGlobalSettings(), args );
  BrowserWindow.getAllWindows().forEach((w) => {
    if (w.webContents.id !== event.sender.id) {
      w.send('dome.ipc.settings.broadcast',args);
    }
  });
  if (DEVEL) saveGlobalSettings();
}

ipcMain.on('dome.ipc.settings.window', applyWindowSettings );
ipcMain.on('dome.ipc.settings.global', applyGlobalSettings );

// --------------------------------------------------------------------------
// --- Renderer-Process Communication
// --------------------------------------------------------------------------

function broadcast( event, ...args )
{
  BrowserWindow.getAllWindows().forEach((w) => {
    w.send( event, ...args );
  });
}

// --------------------------------------------------------------------------
// --- Window Activities
// --------------------------------------------------------------------------

var appName = 'Dome' ;
const MODIFIED = '(*) ' ;

/**
   Sets application window name
   @param {string} title - application name
 */
export function setName(title) {
  appName = title;
}

function setTitle(event,title) {
  let handle = WindowHandles[event.sender.id];
  handle && handle.setTitle( title || appName );
}

function setModified(event,modified) {
  let handle = WindowHandles[event.sender.id];
  if (handle) {
    const w = handle.window;
    if (platform == 'macos')
      w.setDocumentEdited( modified );
    else {
      let title = w.getTitle();
      if (title.startsWith(MODIFIED))
        title = title.substring(MODIFIED.length);
      if (modified)
        title = MODIFIED + title ;
      w.setTitle(title);
    }
  }
}

ipcMain.on('dome.ipc.window.title',setTitle);
ipcMain.on('dome.ipc.window.modified',setModified);

// --------------------------------------------------------------------------
// --- Main Window Web Navigation
// --------------------------------------------------------------------------

import { shell } from 'electron' ;
import { URL } from 'url' ;

function getURL()
{
  if (DEVEL)
    return `http://localhost:${process.env.ELECTRON_WEBPACK_WDS_PORT}` ;
  if (LOCAL)
    return 'file://' + path.join(__dirname,'../renderer/index.html') ;
  return 'file://' + __dirname + '/index.html' ;
}

function navigateURL( event , url ) {
  event.preventDefault();
  const href = new URL( url );
  const main = new URL( getURL() );
  if (href.origin == main.origin)
  {
    const query = href.pathname.substring(1) + href.query + href.hash ;
    event.sender.send('dome.ipc.href', query);
  } else {
    shell.openExternal( url );
  }
}

// --------------------------------------------------------------------------
// --- Lookup for config file
// --------------------------------------------------------------------------

function lookupConfig(wdir) {
  let cwd = wdir = path.resolve(wdir);
  let cfg = '.' + appName.toLowerCase();
  for(;;) {
    const here = path.join(cwd,cfg);
    if (fstat(here)) return here;
    let up = path.dirname(cwd);
    if (up === cwd) break;
    cwd = up;
  }
  const home = path.resolve(app.getPath('home'));
  const user = wdir.startsWith(home) ? wdir : home ;
  return path.join( user, cfg );
}

// --------------------------------------------------------------------------
// --- Browser Window SetUp
// --------------------------------------------------------------------------

function createBrowserWindow( config, argv, wdir )
{

  const isAppWindow = (argv !== undefined && wdir !== undefined);

  const browserArguments = isAppWindow
        ? SYS.WINDOW_APPLICATION_ARGV
        : SYS.WINDOW_PREFERENCES_ARGV ;

  const options = Object.assign(
    {
      show: false,
      backgroundColor: '#f0f0f0',
      webPreferences: {
        nodeIntegration:true,
        additionalArguments: [ browserArguments ]
      }
    },
    config
  );

  const configFile = isAppWindow ? lookupConfig( wdir ) : PATH_WINDOW_SETTINGS ;
  const configData = loadSettings( configFile );

  const { frame, devtools, settings={} } = configData;
  if (frame) {
    const getInt = (v) => v && _.toSafeInteger(v);
    options.x = getInt(frame.x);
    options.y = getInt(frame.y);
    options.width = getInt(frame.width);
    options.height = getInt(frame.height);
  }

  const theWindow = new BrowserWindow( options );
  const wid = theWindow.webContents.id;

  const handle = {
    window: theWindow,
    config: configFile,
    frame, settings, devtools,
    reload: false
  };

  // Keep the window reference (prevent garbage collection)
  WindowHandles[wid] = handle;

  // Emitted when the window is closed.
  theWindow.on('closed', () => {
    saveWindowConfig(handle);
    // Dereference the window object (allow garbage collection)
    delete WindowHandles[wid] ;
  });

  // Load the index.html of the app.
  if (DEVEL || LOCAL)
    process.env['ELECTRON_DISABLE_SECURITY_WARNINGS'] = 'true';

  theWindow.loadURL(getURL());

  // Load Finished
  theWindow.once('ready-to-show' , () => {
    if (DEVEL || LOCAL)
      process.env['ELECTRON_DISABLE_SECURITY_WARNINGS'] = 'false';
    if (DEVEL && devtools)
      theWindow.openDevTools();
    theWindow.show();
  });

  // Focus Management
  theWindow.on('focus', () => theWindow.send('dome.ipc.focus',true));
  theWindow.on('blur',  () => theWindow.send('dome.ipc.focus',false));

  // URL Navigation
  theWindow.webContents.on('will-navigate', navigateURL );
  theWindow.webContents.on('did-navigate-in-page', navigateURL );

  // Application Startup
  theWindow.webContents.on('did-finish-load', () => {
    if (!handle.reload) {
      handle.reload = true;
    } else {
      broadcast('dome.ipc.reload');
    }
    theWindow.send('dome.ipc.command',argv,wdir);
  });

  // Emitted when the window want's to close.
  theWindow.on('close', (evt) => {
    handle.frame = theWindow.getBounds();
    handle.devtools = theWindow.isDevToolsOpened();
    theWindow.send('dome.ipc.closing');
  });

  // Keep track of frame positions (in DEVEL)
  if (DEVEL) {
    const saveFrame = _.debounce( (evt) => {
      handle.frame = theWindow.getBounds();
      handle.devtools = theWindow.isDevToolsOpened();
      saveWindowConfig(handle);
    } , 300);
    theWindow.on('resize',saveFrame);
    theWindow.on('moved',saveFrame);
  }

  return theWindow ;
}

// --------------------------------------------------------------------------
// --- Application Window(s) & Command Line
// --------------------------------------------------------------------------

function stripElectronArgv( argv ) {
  return argv.slice( DEVEL ? 3 : (LOCAL ? 2 : 1) ).filter((p) => !!p);
}

function createPrimaryWindow()
{
  // Initialize Menubar
  Menubar.install();

  // React Developper Tools
  if (DEVEL)
    installExtension(REACT_DEVELOPER_TOOLS,true)
    .catch((err) => {
      console.error('[Dome] Enable to install React dev-tools',err);
    });
  const cwd = process.cwd();
  const wdir = cwd === '/' ? app.getPath('home') : cwd ;
  const argv = stripElectronArgv(process.argv);
  createBrowserWindow({ title: appName } , argv, wdir );
}

var appCount = 1;

function createSecondaryWindow(_event,process_argv,wdir)
{
  const argv = stripElectronArgv(process_argv);
  createBrowserWindow({ title: `${appName} #${++appCount}` }, argv, wdir);
}

function createDesktopWindow()
{
  const instance = appCount++ ;
  const wdir = app.getPath('home');
  createBrowserWindow({ title: `${appName} #${++appCount}` }, [], wdir);
}

// --------------------------------------------------------------------------
// --- Activate Windows (macOS)
// --------------------------------------------------------------------------

function activateWindows() {
  var isFocused = false ;
  var toFocus = undefined ;
  BrowserWindow.getAllWindows().forEach((w) => {
    w.show();
    if (w.isFocused()) isFocused = true ;
    else if (!toFocus) toFocus = w;
  });
  if (!isFocused) {
    if (toFocus) toFocus.focus();
    else {
      // No focusable nor focused window
      createDesktopWindow();
    }
  }
}

// --------------------------------------------------------------------------
// --- Settings Window
// --------------------------------------------------------------------------

var PreferenceWindow = undefined ; // Preference Window

function showSettingsWindow()
{
  if (!PreferenceWindow)
    PreferenceWindow = createBrowserWindow({
      title: appName + ' Settings',
      width: 256,
      height: 248,
      fullscreen: false,
      maximizable: false,
      minimizable: false
    });
  PreferenceWindow.show();
  PreferenceWindow.on('closed',() => PreferenceWindow = undefined);
}

function restoreDefaultSettings()
{
  GlobalSettings = {};
  if (DEVEL) saveGlobalSettings();

  _.forEach( WindowHandles, (handle) => {
    // Keep frame for user comfort
    handle.settings = {};
    handle.devtools = handle.window.isDevToolsOpened();
    if (DEVEL) saveWindowConfig(handle);
  });

  broadcast( 'dome.ipc.settings.defaults' );
}

// --------------------------------------------------------------------------
// --- Main Application Starter
// --------------------------------------------------------------------------

/** Starts the main process. */
export function start() {

  // Ensures second instance triggers the main one
  if (!app.requestSingleInstanceLock()) app.quit();

  // Change default locale
  app.commandLine.appendSwitch('lang','en');

  // Listen to application events
  app.on( 'ready', createPrimaryWindow ); // Wait for Electron init
  app.on( 'activate', activateWindows ); // Mac OSX response to dock
  app.on( 'second-instance', createSecondaryWindow );
  app.on( 'dome.menu.settings', showSettingsWindow );
  app.on( 'dome.menu.defaults', restoreDefaultSettings );

  // At-exit callbacks
  app.on( 'will-quit' , () => {
    saveGlobalSettings();
    System.doExit() ;
  });

  // On macOS the menu bar stays active until the user explicitly quits.
  // On other systems, automatically quit when all windows are closed.
  // Warning: when no event handler is registered, the app automatically
  // quit when all windows are closed.
  app.on( 'window-all-closed', () => {
    if (System.platform !== 'macos') app.quit();
  });

}

// --------------------------------------------------------------------------
// --- MenuBar Management
// --------------------------------------------------------------------------

const MENU_CLICK = (id,callback) => (_item,win,_event) => {
  callback && callback();
  app.emit('dome.menu.clicked', id );
  win.send('dome.ipc.menu.clicked', id );
};

/**
    @summary Define a custom main window menu.
    @description
    Cf. [addMenu](dome_.html#.addMenu) in the renderer process.
*/
export function addMenu( label ) { Menubar.addMenu( label ); }

/**
   @summary Define a custom menu item.
   @description
   Cf. [addMenuItem](dome_.html#.addMenuItem) in the renderer process.
*/
export function addMenuItem( spec )
{
  if ( spec.type === 'separator' ) {
    Menubar.addMenuItem( spec );
  } else {
    const id = spec.id ;
    if (!id) {
      console.error('[Dome] Missing menu-item identifier:',spec);
      return;
    }
    const { callback , ...options } = spec ;
    options.click = MENU_CLICK( id, callback );
    Menubar.addMenuItem( options );
  }
}

/**
   @summary Update a menu item.
   @description
   Cf. [setMenuItem](dome_.html#.setMenuItem) in the renderer process.
*/
export function setMenuItem( options ) {
  const { callback , ...updates } = options ;
  if (callback !== undefined) {
    const id = updates.id ;
    updates.click = MENU_CLICK( id, callback );
  }
  Menubar.setMenuItem( updates );
}

ipcMain.on( 'dome.ipc.menu.addmenu' , addMenu );
ipcMain.on( 'dome.ipc.menu.addmenuitem' , addMenuItem );
ipcMain.on( 'dome.ipc.menu.setmenuitem' , setMenuItem );

// --------------------------------------------------------------------------
