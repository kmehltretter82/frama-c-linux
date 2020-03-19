// --------------------------------------------------------------------------
// --- Menus & MenuBar Management
// --------------------------------------------------------------------------

import { app, BrowserWindow, Menu, MenuItem, shell } from 'electron' ;
import System from 'dome/system' ;

// --------------------------------------------------------------------------
// --- Special Callbacks
// --------------------------------------------------------------------------

function reloadWindow(item, focusedWindow)
{
  if (focusedWindow) {
    reset(); // declared below
    focusedWindow.send('dome.ipc.closing');
    focusedWindow.reload();
  }
}

function toggleFullScreen(item, focusedWindow)
{
  if (focusedWindow)
    focusedWindow.setFullScreen(!focusedWindow.isFullScreen());
}

function toggleDevTools(item, focusedWindow)
{
  if (focusedWindow)
    focusedWindow.toggleDevTools();
}

// --------------------------------------------------------------------------
// --- Menu Utilities
// --------------------------------------------------------------------------

const separator = { type: 'separator' } ;

function concatSep( ...menus ) {
  var submenu = [] ;
  var needsep = false ;
  menus.forEach((items) => {
    const n = items.length ;
    if (n > 0) {
      if (needsep)
        submenu.push( separator );
      submenu = submenu.concat(items);
      needsep = (items[n-1].type !== 'separator') ;
    }
  });
  return submenu ;
}

// --------------------------------------------------------------------------
// --- MacOS Menu Items
// --------------------------------------------------------------------------

const macosAppMenuItems = (name) => [
  {
    label: `About ${name}`,
    role: 'about'
  },
  separator,
  {
    label: `Preferences…`,
    accelerator: 'Command+,',
    click: () => app.emit('dome.menu.settings')
  },
  {
    label: `Restore Defaults`,
    click: () => app.emit('dome.menu.defaults')
  },
  separator,
  {
    label: `Services`,
    submenu: [],
    role: 'services'
  },
  separator,
  {
    label: `Hide ${name}`,
    accelerator: 'Command+H',
    role: 'hide'
  }, {
    label: 'Hide Others',
    accelerator: 'Command+Alt+H',
    role: 'hideothers'
  }, {
    label: 'Show All',
    role: 'unhide'
  },
  separator,
  {
    label: 'Quit',
    accelerator: 'Command+Q',
    role: 'quit'
  }
];

// --------------------------------------------------------------------------
// --- File Menu Items (platform dependant)
// --------------------------------------------------------------------------

var fileMenuItems_custom = [];

const fileMenuItems_linux = [
  {
    label: `Preferences…`,
    click: () => app.emit('dome.menu.settings')
  },
  {
    label: `Restore Defaults`,
    click: () => app.emit('dome.menu.defaults')
  },
  separator,
  {
    label: 'Exit',
    accelerator: 'Ctrl+Q',
    role: 'quit'
  }
];

// --------------------------------------------------------------------------
// --- Edit Menu Items
// --------------------------------------------------------------------------

const editMenuItems = [
  { label: 'Undo',
    accelerator: 'CmdOrCtrl+Z',
    role: 'undo'
  }, {
    label: 'Redo',
    accelerator: 'Shift+CmdOrCtrl+Z',
    role: 'redo'
  },
  separator,
  {
    label: 'Cut',
    accelerator: 'CmdOrCtrl+X',
    role: 'cut'
  }, {
    label: 'Copy',
    accelerator: 'CmdOrCtrl+C',
    role: 'copy'
  }, {
    label: 'Paste',
    accelerator: 'CmdOrCtrl+V',
    role: 'paste'
  }, {
    label: 'Select All',
    accelerator: 'CmdOrCtrl+A',
    role: 'selectall'
  }
];

var editMenuItems_custom = [] ;

// --------------------------------------------------------------------------
// --- View Menu Items
// --------------------------------------------------------------------------

var viewMenuItems_custom = [] ;

const viewMenuItems = (osx) => [
  {
    label: 'Reload',
    accelerator: 'CmdOrCtrl+R',
    click: reloadWindow
  }, {
    label: 'Toggle Full Screen',
    accelerator: (osx ? 'Ctrl+Command+F' : 'F11'),
    click: toggleFullScreen
  }, {
    label: 'Toggle Developer Tools',
    accelerator: (osx ? 'Alt+Command+I' : 'Ctrl+Shift+I'),
    click: toggleDevTools
  }
];

// --------------------------------------------------------------------------
// --- Window Menu Items
// --------------------------------------------------------------------------

const windowMenuItems_linux = [
  {
    label: 'Minimize',
    accelerator: 'CmdOrCtrl+M',
    role: 'minimize'
  }, {
    label: 'Close',
    accelerator: 'CmdOrCtrl+W',
    role: 'close'
  },
  separator,
  {
    label: 'Reopen Window',
    accelerator: 'CmdOrCtrl+Shift+T',
    enabled: false, /*?*/
    key: 'reopenMenuItem', /*?*/
    click: () => { app.emit('activate'); }
  }
];

const windowMenuItems_macos = windowMenuItems_linux.concat([
  {
    label: 'Bring All to Front',
    role: 'front'
  }
]);

// --------------------------------------------------------------------------
// --- Help Menu Items
// --------------------------------------------------------------------------

const helpMenuItems = [
  {
    label: 'Learn More',
    click: function () {
      shell.openExternal('http://electron.atom.io');
    }
  }
];

// --------------------------------------------------------------------------
// --- Update MenuBar (async)
// --------------------------------------------------------------------------

var updateRequired = false ;
var updateTriggered = false ;

function requestUpdate() {
  if (updateRequired && !updateTriggered) {
    updateTriggered = true ;
    setImmediate( install );
  }
}

// --------------------------------------------------------------------------
// --- CustomMenus
// --------------------------------------------------------------------------

var customMenus = [] ;
var customItems = {} ;

function findMenu( label ) {
  switch( label ) {
  case 'File': return fileMenuItems_custom;
  case 'Edit': return editMenuItems_custom;
  case 'View': return viewMenuItems_custom;
  default:
    var theMenu = customMenus.find((m) => m.label === label);
    return theMenu && theMenu.submenu ;
  }
}

export function addMenu( label )
{
  if (findMenu(label)) {
    console.warn(`Already defined menu '${menu}'`);
  } else {
    customMenus.push( { label , submenu:[] } );
  }
  requestUpdate();
}

export function addMenuItem( { menu , key, ...spec } )
{
  var submenu = findMenu( menu );
  if (!submenu) {
    console.error(`[Dome] Unknown menu '${menu}' (menu item #${spec.id || spec.label} undefined)`);
    return;
  }
  if (!spec || spec.type === 'separator') {
    submenu.push( separator );
  } else {
    const id = spec.id ;
    if (!id) {
      console.error('[Dome] Invalid menu item:',spec);
      return;
    }
    if (key) {
      switch(System.platform) {
      case 'macos':
        if (key.startsWith('Cmd+')) spec.accelerator = "Cmd+" + key.substring(4) ;
        if (key.startsWith('Alt+')) spec.accelerator = "Cmd+Alt+" + key.substring(4) ;
        if (key.startsWith('Meta+')) spec.acceperator = "Cmd+Shift+" + key.substring(5) ;
        break;
      case 'windows':
      case 'linux':
      default:
        if (key.startsWith('Cmd+')) spec.accelerator = "Ctrl+" + key.substring(4) ;
        if (key.startsWith('Alt+')) spec.accelerator = "Alt+" + key.substring(4) ;
        if (key.startsWith('Meta+')) spec.acceperator = "Ctrl+Alt+" + key.substring(5) ;
        break;
      }
    }
    const entry = customItems[id] ;
    if (entry) {
      if (!System.DEVEL) {
        console.error('[Dome] Duplicate menu item:',spec);
        return;
      } else {
        if (entry.spec) Object.assign( entry.spec , spec );
        if (entry.item) Object.assign( entry.item , spec );
      }
    } else {
      customItems[id] = { spec } ;
      submenu.push( spec );
    }
  }
  requestUpdate();
}

export function setMenuItem({ id, ...options })
{
  const entry = customItems[id] ;
  if (entry) {
    if (entry.spec) Object.assign( entry.spec , options );
    if (entry.item) Object.assign( entry.item , options );
    if ( options.label || options.type || options.click ) requestUpdate();
  } else
    console.warn(`[Dome] unknown menu item #${id}`);
}

// --------------------------------------------------------------------------
// --- Menu Bar Template
// --------------------------------------------------------------------------

function template() {
  switch(System.platform) {
  case 'macos':
    return [].concat(
      [
        { label: app.name, submenu: macosAppMenuItems(app.name) },
        { label: 'File', submenu: fileMenuItems_custom },
        { label: 'Edit', submenu: concatSep(editMenuItems,editMenuItems_custom) },
        { label: 'View', submenu: concatSep(viewMenuItems_custom,viewMenuItems(true)) }
      ],
      customMenus,
      [
        { label: 'Window', role: 'window', submenu: windowMenuItems_macos },
        { label: 'Help', role: 'help', submenu: helpMenuItems }
      ]
    );
  case 'windows':
  case 'linux':
  default:
    return [].concat(
      [
        { label: 'File', submenu: concatSep(fileMenuItems_custom,fileMenuItems_linux) },
        { label: 'Edit', submenu: concatSep(editMenuItems,editMenuItems_custom) },
        { label: 'View', submenu: concatSep(viewMenuItems_custom,viewMenuItems(false)) }
      ],
      customMenus,
      [
        { label: 'Window', submenu: windowMenuItems_linux },
        { label: 'Help', submenu: helpMenuItems }
      ]
    );
  }
}

// --------------------------------------------------------------------------
// --- MenuBar SetUp
// --------------------------------------------------------------------------

var menubar ;

function registerCustomItems( menu ) {
  menu.items.forEach((item) => {
    const entry = customItems[item.id];
    if (entry) entry.item = item ;
    item.submenu && registerCustomItems( item.submenu );
  });
}

export function install() {
  updateRequired = true;
  updateTriggered = false;
  menubar = Menu.buildFromTemplate(template());
  registerCustomItems( menubar );
  Menu.setApplicationMenu( menubar );
}

// Called by reload above
function reset() {
  fileMenuItems_custom = [] ;
  editMenuItems_custom = [] ;
  viewMenuItems_custom = [] ;
  customMenus = [] ;
  customItems = {} ;
  install();
}

// --------------------------------------------------------------------------
// --- Export Default
// --------------------------------------------------------------------------

export default {
  install,
  addMenu,
  addMenuItem,
  setMenuItem
};

// --------------------------------------------------------------------------
