/**
   @module dome/dialogs
   @description
   Various kind of (modal) dialogs attached to the main application window.
 */

import filepath from 'path' ;
import { remote } from 'electron' ;
import * as System from 'dome/system' ;

// --------------------------------------------------------------------------
// --- Message Box
// --------------------------------------------------------------------------

const defaultItems = [
  { value:undefined },
  { value:true, label:'Ok' }
];

const valueLabel = (v) => {
  switch(v) {
  case undefined: return 'Cancel' ;
  case true: return 'Ok' ;
  case false: return 'No' ;
  default: return ''+v ;
  }
};

const itemLabel = ({value,label}) => label || valueLabel(value) ;
const isDefault = ({value,label}) => value===true || label==='Ok' || label==='Yes' ;
const isCancel = ({value,label}) => !value || label==='Cancel' || label==='No' ;

/**
   @summary Show a configurable message box.
   @parameter {object} options - configuration (see above)
   @return {Promise} the selected option (see above)
   @description
The available fields and options for configuring the dialog are:

| Options | Type | Description |
|:--------|:----:|:------------|
| `kind` | `'none','info','error','warning'` | Icon of the message box |
| `title` | `string` (_opt._) | Heading of message box |
| `message` | `string` | Message text |
| `buttons` | `button[]` (_opt._) | Dialog buttons |
| `defaultValue` | (any) (_opt._) | Value of the default button |
| `cancelValue` | (any) (_opt._) | Value of the cancel key |

The dialog buttons are specified by objects with the following fields:

| Button Field | Type | Description |
|:-------------|:----:|:------------|
| `label` | `string` | Button label |
| `value` | (any) | Button identifier (items only) |

The returned promise object is never rejected, and is asynchronously
resolved into:
- the cancel value if the cancel key is pressed,
- the default value if the enter key is pressed,
- or the value of the clicked button otherwised.

The default buttons are `"Ok"` and `"Cancel"` associated to values `true` and
`undefined`, which are also associated to the enter and cancel keys.
Unless specified, the default value is associated with the first button
with 'true' value or 'Ok' or 'Yes' label,
and the cancel value is the first button with a falsy value or 'Cancel'
or 'No' label.
*/
export function showMessageBox( options )
{
  const {
    kind,
    title,
    message,
    defaultValue,
    cancelValue,
      buttons = defaultItems
  } = options ;

  const labels = buttons.map(itemLabel);
  let defaultId =
      defaultValue === undefined
      ? buttons.findIndex(isDefault)
      : buttons.findIndex((a) => a.value === defaultValue);
  let cancelId =
      cancelValue === undefined
      ? buttons.findIndex(isCancel)
      : buttons.findIndex((a) => a.value === cancelValue);

  if (cancelId === defaultId) cancelId = -1;

  return remote.dialog.showMessageBox(
    remote.getCurrentWindow(),
    {
      type:kind,
      message: message && title,
      detail:  message || title,
      defaultId, cancelId, buttons: labels
    }
  ).then((result) => {
    let itemIndex = result ? result.response : -1 ;
    return itemIndex ? buttons[itemIndex].value : cancelValue ;
  });
}

// --------------------------------------------------------------------------
// --- openFile dialog
// --------------------------------------------------------------------------

const defaultPath = (path) => filepath.extname(path) ? filepath.dirname(path) : path ;

/**
   @summary Show a dialog for opening file.
   @parameter {object} options - configuration (see above)
   @return {Promise} the selected file (see above)
   @description
The available fields and options for configuring the dialog are:

| Options | Type | Description |
|:--------|:----:|:------------|
| `message` | `string` (_opt._) | Prompt message |
| `label` | `string` (_opt._) | Open button label |
| `path` | `filepath` (_opt._) | Initially selected path |
| `hidden` | `boolean` (_opt._) | Show hidden files (not by default) |
| `filters` | `filter[]` (_opt._) | File filters (all files by default) |

The file filters are object with the following fields:

| Filter Field | Type | Description |
|:-------------|:----:|:------------|
| `name` | `string` | Filter name |
| `extensions` | `string[]` | Allowed file extensions, _without_ dots («.») |

A file filter with `extensions:["*"]` would accept any file extension.

The returned promise object will be asynchronously:
- either _resolved_ with `undefined` if no file has been selected,
- or _resolved_ with the selected path

The promise is never rejected.

*/
export function showOpenFile( options )
{
  const { message, label, path, hidden, filters } = options ;
  const properties = [ 'openFile' ];
  if (hidden) properties.push('showHiddenFiles');

  return remote.dialog.showOpenDialog(
    remote.getCurrentWindow(),
    {
      message, buttonLabel: label,
      defaultPath: path && defaultPath(path),
      properties, filters
    }
  ).then(result => {
    if (!result.canceled && result.filePaths && result.filePaths.length > 0)
      return result.filePaths[0] ;
    else
      return undefined ;
  });
}

/**
   @summary Show a dialog for opening file.
   @parameter {object} options - configuration (see above)
   @return {Promise} the selected file(s) (see above)
   @description
The available fields and options for configuring the dialog are:

| Options | Type | Description |
|:--------|:----:|:------------|
| `message` | `string` (_opt._) | Prompt message |
| `label` | `string` (_opt._) | Open button label |
| `path` | `filepath` (_opt._) | Initially selected path |
| `hidden` | `boolean` (_opt._) | Show hidden files (not by default) |
| `filters` | `filter[]` (_opt._) | File filters (all files by default) |

The file filters are object with the following fields:

| Filter Field | Type | Description |
|:-------------|:----:|:------------|
| `name` | `string` | Filter name |
| `extensions` | `string[]` | Allowed file extensions, _without_ dots («.») |

A file filter with `extensions:["*"]` would accept any file extension.

The returned promise object will be asynchronously:
- either _resolved_ with `undefined` if no file has been selected,
- or _resolved_ with the selected paths

The promise is never rejected.

*/
export function showOpenFiles( options )
{
  const { message, label, path, hidden, filters } = options ;
  const properties = [ 'openFile', 'multiSelections' ];
  if (hidden) properties.push('showHiddenFiles');

  return remote.dialog.showOpenDialog(
    remote.getCurrentWindow(),
    {
      message, buttonLabel: label,
      defaultPath: path && defaultPath(path),
      properties, filters
    }
  ).then(result => {
    if (!result.canceled && result.filePaths && result.filePaths.length > 0)
      return result.filePaths ;
    else
      return undefined ;
  });
}


// --------------------------------------------------------------------------
// --- saveFile dialog
// --------------------------------------------------------------------------

/**
   @summary Show a dialog for saving file.
   @parameter {object} options - configuration (see above)
   @return {Promise} the selected path (see above)
   @description
The available fields and options for configuring the dialog are:

| Options | Type | Description |
|:--------|:----:|:------------|
| `message` | `string` (_opt._) | Prompt message |
| `label` | `string` (_opt._) | Save button label |
| `path` | `filepath` (_opt._) | Initially selected path |
| `filters` | `filter[]` (_opt._) | Cf. `openFileDialog` |

The returned promise object will be asynchronously:
- either _resolved_ with `undefined` if no file has been selected,
- or _resolved_ with the selected (single) path.

The promise is never rejected.

*/
export function showSaveFile( options )
{
  const { message, label, path, filters } = options ;

  return remote.dialog.showSaveDialog(
    remote.getCurrentWindow(),
    {
      message, buttonLabel: label,
      defaultPath: path,
      filters
    }
  );
}

// --------------------------------------------------------------------------
// --- openDir dialog
// --------------------------------------------------------------------------

/**
   @summary Show a dialog for selecting directories.
   @parameter {object} options - configuration (see above)
   @return {Promise} the selected directories (see above)
   @description
The available fields and options for configuring the dialog are:

| Options | Type | Description |
|:--------|:----:|:------------|
| `message` | `string` (_opt._) | Prompt message |
| `label` | `string` (_opt._) | Open button label |
| `path` | `filepath` (_opt._) | Initially selected path |
| `hidden` | `boolean` (_opt._) | Show hidden files (not by default) |

The returned promise object will be asynchronously:
- either _resolved_ with `undefined` if no file has been selected,
- or _resolved_ with the selected path

*/
export function showOpenDir( options )
{
  const { message, label, path, hidden } = options ;
  const properties = [ 'openDirectory' ];
  if (hidden) properties.push('showHiddenFiles');

  switch(System.platform) {
    case 'macos':   properties.push( 'createDirectory' ); break;
  case 'windows': properties.push( 'promptToCreate' ); break;
  }

  return remote.dialog.showOpenDialog(
    remote.getCurrentWindow(),
    {
      message,
      buttonLabel: label,
      defaultPath: path,
      properties
    }
  ).then(result => {
    if (!result.canceled && result.filePaths && result.filePaths.length > 0)
      return result.filePaths[0] ;
    else
      return undefined ;
  });
}

// --------------------------------------------------------------------------
