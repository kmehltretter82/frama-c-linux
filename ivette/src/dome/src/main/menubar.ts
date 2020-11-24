// --------------------------------------------------------------------------
// --- Menus & MenuBar Management
// --------------------------------------------------------------------------

/* eslint-disable max-len */
/* eslint-disable @typescript-eslint/camelcase */

import { app, ipcMain, BrowserWindow, Menu, MenuItem, shell } from 'electron';
import * as System from 'dome/system';

// --------------------------------------------------------------------------
// --- Special Callbacks
// --------------------------------------------------------------------------

function reloadWindow() {
  reset(); // declared below
  BrowserWindow.getAllWindows().forEach((win) => {
    if (win) {
      try {
        win.webContents.send('dome.ipc.closing');
        win.reload();
      } catch (err) {
        console.warn('[Reload]', win.id, err);
      }
    }
  });
}

function toggleFullScreen(_item: MenuItem, focusedWindow: BrowserWindow) {
  if (focusedWindow)
    focusedWindow.setFullScreen(!focusedWindow.isFullScreen());
}

function toggleDevTools(_item: MenuItem, focusedWindow: BrowserWindow) {
  if (focusedWindow)
    focusedWindow.webContents.toggleDevTools();
}

// --------------------------------------------------------------------------
// --- Menu Utilities
// --------------------------------------------------------------------------

export type MenuItemSpec = Electron.MenuItemConstructorOptions;
export type MenuSpec = MenuItemSpec[];

const Separator: MenuItemSpec = { type: 'separator' };

function concatSep(...menus: MenuSpec[]): MenuSpec {
  let menu: MenuItemSpec[] = [];
  let needsep = false;
  menus.forEach((items) => {
    const n = items.length;
    if (n > 0) {
      if (needsep) menu.push(Separator);
      menu = menu.concat(items);
      needsep = (items[n - 1].type !== 'separator');
    }
  });
  return menu;
}

// --------------------------------------------------------------------------
// --- MacOS Menu Items
// --------------------------------------------------------------------------

const macosAppMenuItems = (appName: string): MenuSpec => [
  {
    label: `About ${appName}`,
    role: 'about',
  },
  Separator,
  {
    label: 'Preferences…',
    accelerator: 'Command+,',
    click: () => ipcMain.emit('dome.menu.settings'),
  },
  {
    label: 'Restore Defaults',
    click: () => ipcMain.emit('dome.menu.defaults'),
  },
  Separator,
  {
    label: 'Services',
    submenu: [],
    role: 'services',
  },
  Separator,
  {
    label: `Hide ${appName}`,
    accelerator: 'Command+H',
    role: 'hide',
  }, {
    label: 'Hide Others',
    accelerator: 'Command+Alt+H',
    role: 'hideOthers',
  }, {
    label: 'Show All',
    role: 'unhide',
  },
  Separator,
  {
    label: 'Quit',
    accelerator: 'Command+Q',
    role: 'quit',
  },
];

// --------------------------------------------------------------------------
// --- File Menu Items (platform dependant)
// --------------------------------------------------------------------------

const fileMenuItems_custom: MenuSpec = [];

const fileMenuItems_linux: MenuSpec = [
  {
    label: 'Preferences…',
    click: () => ipcMain.emit('dome.menu.settings'),
  },
  {
    label: 'Restore Defaults',
    click: () => ipcMain.emit('dome.menu.defaults'),
  },
  Separator,
  {
    label: 'Exit',
    accelerator: 'Ctrl+Q',
    role: 'quit',
  },
];

// --------------------------------------------------------------------------
// --- Edit Menu Items
// --------------------------------------------------------------------------

const editMenuItems_custom: MenuSpec = [];

const editMenuItems: MenuSpec = [
  {
    label: 'Undo',
    accelerator: 'CmdOrCtrl+Z',
    role: 'undo',
  }, {
    label: 'Redo',
    accelerator: 'Shift+CmdOrCtrl+Z',
    role: 'redo',
  },
  Separator,
  {
    label: 'Cut',
    accelerator: 'CmdOrCtrl+X',
    role: 'cut',
  }, {
    label: 'Copy',
    accelerator: 'CmdOrCtrl+C',
    role: 'copy',
  }, {
    label: 'Paste',
    accelerator: 'CmdOrCtrl+V',
    role: 'paste',
  }, {
    label: 'Select All',
    accelerator: 'CmdOrCtrl+A',
    role: 'selectAll',
  },
];

// --------------------------------------------------------------------------
// --- View Menu Items
// --------------------------------------------------------------------------

const viewMenuItems_custom: MenuSpec = [];

const viewMenuItems = (osx: boolean): MenuSpec => [
  {
    label: 'Reload',
    accelerator: 'CmdOrCtrl+R',
    click: reloadWindow,
  }, {
    label: 'Toggle Full Screen',
    accelerator: (osx ? 'Ctrl+Command+F' : 'F11'),
    click: toggleFullScreen,
  }, {
    label: 'Toggle Developer Tools',
    accelerator: (osx ? 'Alt+Command+I' : 'Ctrl+Shift+I'),
    click: toggleDevTools,
  },
];

// --------------------------------------------------------------------------
// --- Window Menu Items
// --------------------------------------------------------------------------

const windowMenuItems_linux: MenuSpec = [
  {
    label: 'Minimize',
    accelerator: 'CmdOrCtrl+M',
    role: 'minimize',
  }, {
    label: 'Close',
    accelerator: 'CmdOrCtrl+W',
    role: 'close',
  },
  Separator,
  {
    label: 'Reopen Window',
    accelerator: 'CmdOrCtrl+Shift+T',
    enabled: false,
    click: () => { app.emit('activate'); },
  },
];

const windowMenuItems_macos: MenuSpec = windowMenuItems_linux.concat([
  {
    label: 'Bring All to Front',
    role: 'front',
  },
]);

// --------------------------------------------------------------------------
// --- Help Menu Items
// --------------------------------------------------------------------------

const helpMenuItems: MenuSpec = [
  {
    label: 'Learn More',
    click() {
      shell.openExternal('http://electron.atom.io');
    },
  },
];

// --------------------------------------------------------------------------
// --- Update MenuBar (async)
// --------------------------------------------------------------------------

let updateRequired = false;
let updateTriggered = false;

function requestUpdate() {
  if (updateRequired && !updateTriggered) {
    updateTriggered = true;
    setImmediate(install);
  }
}

// --------------------------------------------------------------------------
// --- CustomMenus
// --------------------------------------------------------------------------

interface CustomMenu extends Electron.MenuItemConstructorOptions {
  label: string;
  submenu: MenuSpec;
}

const customMenus: CustomMenu[] = [];

type ItemEntry = { spec: MenuItemSpec; item?: MenuItem };

const customItems = new Map<string, ItemEntry>();

function findMenu(label: string): MenuSpec | undefined {
  switch (label) {
    case 'File': return fileMenuItems_custom;
    case 'Edit': return editMenuItems_custom;
    case 'View': return viewMenuItems_custom;
    default: {
      const cm = customMenus.find((m) => m.label === label);
      return cm && cm.submenu;
    }
  }
}

export function addMenu(label: string) {
  if (findMenu(label)) {
    console.warn(`Already defined menu '${label}'`);
  } else {
    customMenus.push({ label, submenu: [] });
  }
  requestUpdate();
}

export interface CustomMenuItem extends MenuItemSpec {
  menu: string;
  id: string;
  key?: string;
}

export interface Separator {
  menu: string;
  type: 'separator';
}

export type CustomMenuItemSpec = Separator | CustomMenuItem;

export function addMenuItem(custom: CustomMenuItemSpec) {
  const menuSpec = findMenu(custom.menu);
  if (!menuSpec) {
    console.error('[Dome] Unknown menu', custom);
    return;
  }
  if (custom.type === 'separator') {
    menuSpec.push(Separator);
  } else {
    const { id, key, ...spec } = custom;
    if (key) {
      switch (System.platform) {
        case 'macos':
          if (key.startsWith('Cmd+')) spec.accelerator = `Cmd+${key.substring(4)}`;
          if (key.startsWith('Alt+')) spec.accelerator = `Cmd+Alt+${key.substring(4)}`;
          if (key.startsWith('Meta+')) spec.accelerator = `Cmd+Shift+${key.substring(5)}`;
          break;
        case 'windows':
        case 'linux':
        default:
          if (key.startsWith('Cmd+')) spec.accelerator = `Ctrl+${key.substring(4)}`;
          if (key.startsWith('Alt+')) spec.accelerator = `Alt+${key.substring(4)}`;
          if (key.startsWith('Meta+')) spec.accelerator = `Ctrl+Alt+${key.substring(5)}`;
          break;
      }
    }
    const entry = customItems.get(id);
    if (entry) {
      if (!System.DEVEL) {
        console.error('[Dome] Duplicate menu item:', custom);
        return;
      }
      if (entry.spec) Object.assign(entry.spec, spec);
      if (entry.item) Object.assign(entry.item, spec);

    } else {
      customItems.set(id, { spec });
      menuSpec.push(spec);
    }
  }
  requestUpdate();
}

export function setMenuItem({ id, ...options }: CustomMenuItem) {
  const entry = customItems.get(id);
  if (entry) {
    if (entry.spec) Object.assign(entry.spec, options);
    if (entry.item) Object.assign(entry.item, options);
    if (options.label || options.type || options.click) requestUpdate();
  } else
    console.warn(`[Dome] unknown menu item #${id}`);
}

// --------------------------------------------------------------------------
// --- Menu Bar Template
// --------------------------------------------------------------------------

function template(): CustomMenu[] {
  switch (System.platform) {
    case 'macos':
      return ([] as CustomMenu[]).concat(
        [
          { label: app.name, submenu: macosAppMenuItems(app.name) },
          { label: 'File', submenu: fileMenuItems_custom },
          { label: 'Edit', submenu: concatSep(editMenuItems, editMenuItems_custom) },
          { label: 'View', submenu: concatSep(viewMenuItems_custom, viewMenuItems(true)) },
        ],
        customMenus,
        [
          { label: 'Window', role: 'window', submenu: windowMenuItems_macos },
          { label: 'Help', role: 'help', submenu: helpMenuItems },
        ],
      );
    case 'windows':
    case 'linux':
    default:
      return ([] as CustomMenu[]).concat(
        [
          { label: 'File', submenu: concatSep(fileMenuItems_custom, fileMenuItems_linux) },
          { label: 'Edit', submenu: concatSep(editMenuItems, editMenuItems_custom) },
          { label: 'View', submenu: concatSep(viewMenuItems_custom, viewMenuItems(false)) },
        ],
        customMenus,
        [
          { label: 'Window', submenu: windowMenuItems_linux },
          { label: 'Help', submenu: helpMenuItems },
        ],
      );
  }
}

// --------------------------------------------------------------------------
// --- MenuBar SetUp
// --------------------------------------------------------------------------

let menubar: Menu;

function registerCustomItems(menu: Menu) {
  menu.items.forEach((item: MenuItem) => {
    const entry = customItems.get(item.id);
    if (entry) entry.item = item;
    if (item.submenu) registerCustomItems(item.submenu);
  });
}

// Initialize the menubar machinery
export function install() {
  updateRequired = true;
  updateTriggered = false;
  menubar = Menu.buildFromTemplate(template());
  registerCustomItems(menubar);
  Menu.setApplicationMenu(menubar);
}

// Called by reload above
function reset() {
  fileMenuItems_custom.length = 0;
  editMenuItems_custom.length = 0;
  viewMenuItems_custom.length = 0;
  customMenus.length = 0;
  customItems.clear();
  install();
}

// --------------------------------------------------------------------------
