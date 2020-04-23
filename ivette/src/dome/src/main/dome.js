/**
   @module dome(main)
   @description

   ## Dome Application (Main Process)

   This module manages the electron main-process of the application.
   Your application will launch on `Dome.start()`:

   @example
   // src/main/index.js:
   import Dome from 'dome' ;
   Dome.start();
*/

import {
  app,
  ipcMain,
  BrowserWindow
} from 'electron' ;

import _ from 'lodash' ;
import fs from 'fs' ;
import path from 'path' ;
import Menubar from './menubar.js' ;
import System from 'dome/system' ;
import installExtension , { REACT_DEVELOPER_TOOLS } from 'dome/devtools' ;

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

const APP_DIR = app.getPath('userData');
const APP_SETTINGS = path.join( APP_DIR , 'Settings.json' );

var s_frames = {} ;
var s_globals = {} ;
var s_application = {} ;
var s_preferences = {} ;

function loadSettings() {
  try {
    if (!fstat( APP_SETTINGS )) return;
    const content = fs.readFileSync( APP_SETTINGS, { encoding: 'utf8' } );
    const loaded = JSON.parse( content );
    const MERGE = (store,field) => _.merge( store , _.get( loaded , field ));
    s_frames = MERGE( s_frames , 'frames' );
    s_globals = MERGE( s_globals, 'globals' );
    s_application = MERGE( s_application, 'application' );
    s_preferences = MERGE( s_preferences, 'preferences' );
  } catch(err) {
    console.error("[Dome] Can not load application settings\n" + err);
  }
}

function saveSettings() {
  try {
    if (!fstat( APP_DIR )) fs.mkdirSync( APP_DIR );
    const saved = {
      globals: s_globals,
      application: s_application,
      preferences: s_preferences,
      frames: s_frames
    };
    const content = JSON.stringify( saved, undefined, DEVEL ? 2 : 0 );
    fs.writeFileSync( APP_SETTINGS, content, { encoding: 'utf8' }, errorSettings );
  } catch(err) {
    errorSettings(err);
  }
}

const fireSaveSettings = _.debounce( saveSettings , 50 );

function errorSettings(err) {
  if (err) console.error("[Dome] Can not save application settings\n" + err);
}

function remoteSyncSettings(event)
{
  const isSetting = windowSettings && windowSettings.id === event.frameId ;
  event.returnValue = {
    globals: s_globals,
    settings: isSetting ? s_preferences : s_application
  };
}

function remoteSaveWindowSettings(event,patches)
{
  const isSetting = windowSettings && windowSettings.id === event.frameId ;
  _.merge( isSetting ? s_preferences : s_application , patches );
  saveSettings();
}

function remoteSaveGlobalSettings(event,patches)
{
  _.merge( s_globals , patches );
  saveSettings();
  BrowserWindow.getAllWindows().forEach((win) => {
    if (win.id !== event.frameId)
      win.send('dome.ipc.settings.update',patches);
  });
}

ipcMain.on('dome.ipc.settings.sync', remoteSyncSettings );
ipcMain.on('dome.ipc.settings.window', remoteSaveWindowSettings );
ipcMain.on('dome.ipc.settings.global', remoteSaveGlobalSettings );

// --------------------------------------------------------------------------
// --- Active Windows
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
  let w = BrowserWindow.fromId( event.frameId );
  w.setTitle( title || appName );
}

function setModified(event,modified) {
  let w = BrowserWindow.frameId( event.frameId );
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
// --- Browser Window SetUp
// --------------------------------------------------------------------------

const windowsHandle = {} ; // Prevent live windows to be garbage collected

function createBrowserWindow( config, isMain=true )
{

  const argv = isMain
        ? System.WINDOW_APPLICATION_ARGV
        : System.WINDOW_PREFERENCES_ARGV ;

  const options = _.merge(
    {
      show: false,
      backgroundColor: '#f0f0f0',
      webPreferences: {
        nodeIntegration:true,
        additionalArguments: [ argv ]
      }
    }
    , config );

  const frameId = isMain ? 'application' : 'preferences' ;
  const frame = _.get( s_frames, frameId );
  const getInt = (v) => v && _.toSafeInteger(v);
  if (frame) {
    options.x = getInt(frame.x);
    options.y = getInt(frame.y);
    options.width = getInt(frame.width);
    options.height = getInt(frame.height);
  }

  const theWindow = new BrowserWindow( options );

  // Load the index.html of the app.
  if (DEVEL || LOCAL)
    process.env['ELECTRON_DISABLE_SECURITY_WARNINGS'] = 'true';

  theWindow.loadURL(getURL());

  // Load Finished
  theWindow.once('ready-to-show' , () => {
    if (DEVEL || LOCAL)
      process.env['ELECTRON_DISABLE_SECURITY_WARNINGS'] = 'false';
    if (DEVEL)
      theWindow.openDevTools();
    theWindow.show();
  });

  // Focus Management
  theWindow.on('focus', () => theWindow.send('dome.ipc.focus',true));
  theWindow.on('blur',  () => theWindow.send('dome.ipc.focus',false));

  // URL Navigation
  theWindow.webContents.on('will-navigate', navigateURL );
  theWindow.webContents.on('did-navigate-in-page', navigateURL );
  theWindow.webContents.on('did-finish-load', () => broadcast('dome.ipc.reload'));

  // Emitted when the window want's to close.
  theWindow.on('close', (evt) => {
    theWindow.send('dome.ipc.closing');
    const frame = theWindow.getBounds();
    _.set( s_frames, frameId , frame );
  });

  // Keep track of frame positions (in DEVEL)
  if (DEVEL) {
    const reframe = _.debounce( (evt) => {
      const frame = theWindow.getBounds();
      _.set( s_frames, frameId , frame );
      saveSettings();
    } , 300);
    theWindow.on('resize',reframe);
    theWindow.on('moved',reframe);
  }

  // Keep the window reference to prevent destruction
  const wid = theWindow.id ;
  windowsHandle[ wid ] = theWindow ;

  // Emitted when the window is closed.
  theWindow.on('closed', () => {
    // Dereference the window object to actually destroy it
    delete windowsHandle[ wid ] ;
  });

  return theWindow ;
}

// --------------------------------------------------------------------------
// --- Application Window(s)
// --------------------------------------------------------------------------

function filterArgv( argv ) {
  return argv.slice( DEVEL ? 3 : (LOCAL ? 2 : 1) ).filter((p) => p);
}

function sendCommand( win, argv, wdir ) {
  win.webContents.on('did-finish-load', () => {
    win.webContents.send('dome.ipc.command',argv,wdir);
  });
}

function createPrimaryWindow()
{
  // Initialize Menubar
  Menubar.install();

  // Initialize Settings
  loadSettings();

  // React Developper Tools
  if (DEVEL)
    installExtension(REACT_DEVELOPER_TOOLS,true);

  const primary = createBrowserWindow({ title: appName } , true);
  const wdir = process.cwd() === '/' ? app.getPath('home') : process.cwd() ;
  sendCommand( primary , filterArgv(process.argv) , wdir );
}

var appCount = 1;

function createSecondaryWindow(_event,argv,wdir)
{
  const secondary = createBrowserWindow({ title: `${appName} #${++appCount}` }, true);
  sendCommand( secondary, filterArgv(argv), wdir );
}

function createDesktopWindow()
{
  const instance = appCount++ ;
  const secondary = createBrowserWindow({ title: `${appName} #${++appCount}` }, true);
  sendCommand( secondary , [] , app.getPath('home') );
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

var windowSettings = undefined ; // Preference Window

function showSettingsWindow()
{
  if (!windowSettings)
    windowSettings = createBrowserWindow({
      title: appName + ' Settings',
      width: 256,
      height: 248,
      fullscreen: false,
      maximizable: false,
      minimizable: false
    }, false);
  windowSettings.show();
  windowSettings.on('closed',() => windowSettings = undefined);
}

function restoreDefaultSettings()
{
  s_globals = {} ;
  s_preferences = {} ;
  s_application = {} ;
  s_frames = {} ;
  fireSaveSettings();
  fireSaveSettings.flush();
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

  // Listen to window events
  app.on( 'ready', createPrimaryWindow ); // Wait for Electron init
  app.on( 'activate', activateWindows ); // Mac OSX response to dock
  app.on( 'second-instance', createSecondaryWindow );
  app.on( 'dome.menu.settings', showSettingsWindow );
  app.on( 'dome.menu.defaults', restoreDefaultSettings );

  // Performing on-exit callbacks
  app.on( 'will-quit' , () => {
    System.doExit() ;
    fireSaveSettings();
    fireSaveSettings.flush();
  });

  // On OS X menu bar stay active until the user quits explicitly from menu.
  // On other systems, quit when all windows are closed.
  // Warning: when no event handler is registered, the app automatically
  // quit when all windows are closed.
  app.on( 'window-all-closed', () => {
    if (System.platform !== 'macos') app.quit();
  });

}

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
// --- Export Default
// --------------------------------------------------------------------------

export default {
  platform,
  DEVEL,
  setName,
  start,
  addMenu,
  addMenuItem,
  setMenuItem
} ;

// --------------------------------------------------------------------------
