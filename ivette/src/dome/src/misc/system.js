/**
   @packageDocumentation
   @module dome/system
*/

// --------------------------------------------------------------------------
// --- Evolved Spawn Process
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import Emitter from 'events' ;
import Exec from 'child_process' ;
import fspath from 'path' ;
import fs from 'fs' ;
import { app, remote } from 'electron' ;

// --------------------------------------------------------------------------
// --- Platform Specificities
// --------------------------------------------------------------------------

var thePlatform = 'linux' ;
{
  switch( process.platform ) {
  case 'darwin':
    thePlatform = 'macos'; break;
  case 'win32':
  case 'win64':
    thePlatform = 'windows'; break;
  case 'aix':
  case 'freebsd':
  case 'linux':
  case 'openbsd':
  case 'sunos':
    thePlatform = 'linux'; break;
  default:
    console.warn(`Unkwnon OS platform '${process.platform}' (fallback to 'linux')`);
    thePlatform = 'linux'; break;
  }
}

/**
   @summary System platform.
   @description
   Similar to `process.platform`, but fall into fewer categories:
   - `'macos'` for Mac OSX,
   - `'windows'` for Windows (32 or 64)
   - `'linux'` for most unix-like platforms

Non-recognized platforms will fallback to `'linux'` with the emission of a warning.
*/
export const platform = thePlatform ;

// --------------------------------------------------------------------------
// --- Logging
// --------------------------------------------------------------------------

/** Development mode flag */
export const DEVEL = process.env.NODE_ENV !== 'production' ;

// --------------------------------------------------------------------------
// --- System Emitter
// --------------------------------------------------------------------------

export const emitter = new Emitter();
{
  emitter.setMaxListeners(250);
}

// --------------------------------------------------------------------------
// --- At Exit
// --------------------------------------------------------------------------

const exitJobs = [];

function exitJob(job,...args) {
  try { job(...args); }
  catch(err) { console.err('[Dome] atExit:',err); }
}

/**
   @summary Execute a routine at exit.
   @param {function} callback - the function to be called when application is closing
   @param {...any} [args] - the argument to be provided to the callback
   @description
   Exceptions thrown by the function are captured and reported on the console.
 */
export function atExit(callback,...args) {
  exitJobs.push(() => exitJob(callback,...args));
}

/**
   @summary Execute a callback at exit on each elements of a collection.
   @param {array|object} elements - the collection to iterate over
   @param {function} callback - the function to be called on each element
   @description
   The function will be invoked with `callback(value,key,elements)` via
   the [Lodash `_.forOwn()`](https://lodash.com/docs/4.17.10#forOwn) iterator.

   Exceptions thrown by the function are individually captured and reported
   on the console for each element in the object or array.
 */
export function atExitForEach(elements,callback) {
  atExit(() =>
         _.forOwn(elements,(value,key,data) => exitJob(callback,value,key,data))
        );
}

/** Execute all pending exit jobs (and flush the list). */
export function doExit() {
  exitJobs.forEach((f) => f());
  exitJobs.length = 0;
}

// --------------------------------------------------------------------------
// --- Command Line Arguments
// --------------------------------------------------------------------------

var COMMAND_WDIR = undefined ;
var COMMAND_ARGV = undefined ;

function SET_COMMAND(argv,wdir) {
  COMMAND_ARGV = argv ;
  COMMAND_WDIR = wdir ;
}

// --------------------------------------------------------------------------
// --- User's Directories
// --------------------------------------------------------------------------

const appProxy = app || remote.app ;

/** Returns user's home directory. */
export function getHome() { return appProxy.getPath('home'); }

/** Returns user's desktop directory. */
export function getDesktop() { return appProxy.getPath('desktop'); }

/** Returns user's documents directory. */
export function getDocuments() { return appProxy.getPath('documents'); }

/** Returns user's downloads directory. */
export function getDownloads() { return appProxy.getPath('downloads'); }

/**
   @summary Working directory (Application Window).
   @return {string} absolute path
   @description
   This the current working directory from where the application window
   was opened.

   The function returns `undefined` until the `dome.command` event has been emitted
   from the `Main` process.

   See also [Dome.onCommand](dome_.html#.onCommand) event handler.
*/
export function getWorkingDir() { return COMMAND_WDIR; }

/**
   @summary Returns the current process ID.
   @return {number} `process.pid`
 */
export function getPID() { return process.pid; }

/**
   @summary Command-line arguments (Application Window).
   @return {Array.<string>} command-line arguments
   @description
   This the command-line arguments used to open the application window.

   The function returns `undefined` until the `dome.command` event has been emitted
   from the `Main` process.

   See also [Dome.onCommand](dome_.html#.onCommand) event handler.
*/
export function getArguments() { return COMMAND_ARGV; }

/** @summary Returns static assets.
    @param {string} [...path] - a sequecne of path segments
    @description
    Returns the path to the associated `./static/<...path>` of your application.
    The `./static/` directory is automatically packed into your application
    by Dome thanks to `electron-webpack` default configuration.
*/
export function getStatic(...path) { return fspath.join( __static, ...path ); }

// --------------------------------------------------------------------------
// --- File Join
// --------------------------------------------------------------------------

/**
   @summary Join file paths.
   @param {string} [...paths] - a sequence of path segments
   @return {string} the joined filepath
   @description
   Same as [Node `path.join`](https://nodejs.org/dist/latest-v12.x/docs/api/path.html#path_path_join_paths)
*/
export const join = fspath.join ;

/**
   @summary Absolute (joined) file paths.
   @param {string} [...paths] - a sequence of path segments
   @return {string} the corresponding absolute path
   @description
   Same as [Node `path.resolve`](https://nodejs.org/dist/latest-v12.x/docs/api/path.html#path_path_resolve_paths)
*/
export const resolve = fspath.resolve ;

/**
   @summary Dirname of path.
   @param {string} path - a file path
   @return {string} the dirname of the path
   @description
   Same as [Node `path.dirname`](https://nodejs.org/dist/latest-v12.x/docs/api/path.html#path_path_dirname_path)
*/
export const dirname = fspath.dirname ;

/**
   @summary Basename of path.
   @param {string} path - a file path
   @param {string} [ext] - file extension to remove
   @return {string} the basename of the path
   @description
   Same as [Node `path.basename`](https://nodejs.org/dist/latest-v12.x/docs/api/path.html#path_path_basename_path_ext)
*/
export const basename = fspath.basename ;

/**
   @summary File extension of path.
   @param {string} path - a file path
   @return {string} the file extension of the path
   @description
   Same as [Node `path.extname`](https://nodejs.org/dist/latest-v12.x/docs/api/path.html#path_path_extname_path)
*/
export const extname = fspath.extname ;

// --------------------------------------------------------------------------
// --- File Stats
// --------------------------------------------------------------------------

/**
   @summary Return an `fs.stat()` object for the path.
   @param {string} path - the file path
   @return {Promise<fs.Stats>} the file stats
   @description
Promisified [Node `fs.stat`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_stat_path_callback).

Returns a (promised) [Node `fs.Stats`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_class_fs_stats) object,
including the following usefull fields and methods (and more):
 - `stats.isFile()` returns `true` for a regular file
 - `stats.isDirectory()` returns `true` for a directory
 - `stats.mode` the bitfield (integer) of the file access mode
 - `stats.size` the size of the file (in bytes)
 - `stats.mtime` last modification time stamp (javascript `Date` object)

The promise is rejected if the file does not exists.
*/
export function fileStat( path ) {
  return new Promise((resolve,reject) => {
    fs.stat( path, (err,data) => err ? reject(err) : resolve(data) );
  });
}

/**
   @summary Check is a path exists and is a regular file.
   @param {string} path - the file path
   @return {boolean} synchronous check
*/
export function isFile( path )
{
  try {
    return path && fs.statSync( path ).isFile();
  } catch(_err) {
    return false;
  }
}

/**
   @summary Check is a path exists and is a directory.
   @param {string} path - the dir path
   @return {boolean} synchronous check
*/
export function isDirectory( path )
{
  try {
    return path && fs.statSync( path ).isDirectory();
  } catch(_err) {
    return false;
  }
}

/**
   @summary Check is a path exists and is a file or directory.
   @param {string} path - the dir path
   @return {boolean} synchronous check
*/
export function exists( path )
{
  try {
    if (!path) return false;
    let stats = fs.statSync( path );
    return stats.isFile() || stats.isDirectory();
  } catch(_err) {
    return false;
  }
}

// --------------------------------------------------------------------------
// --- Read File
// --------------------------------------------------------------------------

/**
   @summary Reads a textual file contents.
   @param {string} path - the file path
   @return {Promise<string>} the file's content
   @description
   Promisified
   [Node `fs.readFile`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_readfile_path_options_callback)
   using `UTF-8` encoding.
 */
export function readFile( path ) {
  return new Promise((resolve,reject) => {
    fs.readFile( path, 'UTF-8', (err,data) => err ? reject(err) : resolve(data) );
  });
}

// --------------------------------------------------------------------------
// --- Write File
// --------------------------------------------------------------------------

/**
   @summary Writes a textual content in a file.
   @param {string} path - the file path
   @param {string} content - the content to write in
   @return {Promise} to handle the request.
   @description
   Promisified
   [Node `fs.writeFile`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_writefile_file_data_options_callback)
   using `UTF-8` encoding.
 */
export function writeFile( path , content ) {
  return new Promise((resolve,reject) => {
    fs.writeFile( path, content, 'UTF-8', (err) => err ? reject(err) : resolve() );
  });
}

// --------------------------------------------------------------------------
// --- Copy File
// --------------------------------------------------------------------------

/**
   @summary Copy file to a new path.
   @param {string} srcPath - the source file path
   @param {string} tgtPath - the target file path
   @return {Promise} to handle the request.
   @description
   Promisified
   [Node `fs.copyFile`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_copyfile_src_dest_flags_callback)
   using `UTF-8` encoding.
 */
export function copyFile( srcPath , tgtPath ) {
  return new Promise((resolve,reject) => {
    fs.copyFile( srcPath, tgtPath, (err) => err ? reject(err) : resolve() );
  });
}

// --------------------------------------------------------------------------
// --- Read Directory
// --------------------------------------------------------------------------

/**
   @summary Reads a directory.
   @param {string} path - the directory path
   @return {Promise<string[]>} the directory content as an array of its file names (not full path)
   @description
   Promisified
   [Node `fs.readdir`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_readdir_path_options_callback).

   Uses `UTF-8` encoding to obtain (relative) file names instead of byte buffers. On MacOS, `.DS_Store` entries
   are filtered out.
*/
export function readDir( path ) {
  const filterDir = (f) => f !== '.DS_Store' ;
  return new Promise((resolve,reject) => {
    fs.readdir( path, 'UTF-8', (err,files) => err ? reject(err) : resolve(files.filter(filterDir)) );
  });
}

// --------------------------------------------------------------------------
// --- Make Directory
// --------------------------------------------------------------------------

/**
   @summary Creates a new directory.
   @param {string} path - the directory path
   @param {object} options - permissions and mode (defaults to recursive, `0o777`)
   @return {Promise} to handle the request.
   @description
   Promisified
   [Node `fs.mkdir`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_mkdir_path_options_callback).
   Options:
   - `mode:number` permission modes (default is `0o777`)
   - `recursive:boolean` recursively create parent directories (default is `true`)
*/
export function mkDir( path, { recursive=true, mode=0o777 }={} )
{
  return new Promise((resolve,reject) => {
    fs.mkdir( path, { recursive, mode }, (err) => err ? reject(err) : resolve() );
  });
}

// --------------------------------------------------------------------------
// --- Remove File
// --------------------------------------------------------------------------

/**
   @summary Remove a file.
   @param {string} path - the file path to unlink
   @return {Promise} to handle the request.
   @description
   Promisified
   [Node `fs.unlink`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_unlink_path_callback)
*/
export function remove( path )
{
  return new Promise((resolve,reject) => {
    fs.unlink( path, (err) => err ? reject(err) : resolve() );
  });
}

// --------------------------------------------------------------------------
// --- Remove Directory
// --------------------------------------------------------------------------

// Not (yet) implemented in Node for Electron
function rmDirNonRec(path) {
  return new Promise((resolve,reject) => {
    fs.rmdir( path, (err) => err ? reject(err) : resolve() );
  });
}

// Not (yet) implemented in Node for Electron
function rmDirRec(path) {
  try {
    let stats = fs.statSync( path );
    if (stats.isFile()) {
      return remove(path);
    }
    if (stats.isDirectory()) {
      const rmDirSub = (name) => rmDirRec(fspath.join(path,name));
      return readDir(path)
        .then((names) => Promise.all(names.map(rmDirSub)))
        .then(() => rmDirNonRec(path));
    }
    return Promise.resolve();
  } catch(_err) {
    return Promise.resolve();
  }
}

/**
   @summary Remove a directory.
   @param {string} path - the directory path
   @param {object|boolean} [options] - deletion mode (defaults to non-recursive)
   @return {Promise} to handle the request.
   @description
   Promisified
   [Node `fs.rmdir`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_mkdir_path_options_callback).
   Options:
   - `recursive:boolean` recursively remove sub-directories (default is `true`)
*/
export function rmDir( path, { recursive=true }={} )
{
  return recursive ? rmDirRec( path ) : rmDirNonRec( path );
}

// --------------------------------------------------------------------------
// --- Rename File
// --------------------------------------------------------------------------

/**
   @summary Rename of file of direcory.
   @param {string} oldPath - the old path
   @param {string} newPath - the new path
   @return {Promise} to handle the request.
   @description
   Promisified
   [Node `fs.rename`](https://nodejs.org/dist/latest-v12.x/docs/api/fs.html#fs_fs_rename_oldpath_newpath_callback)
*/
export function rename( oldPath, newPath )
{
  return new Promise((resolve,reject) => {
    fs.rename( oldPath, newPath, (err) => err ? reject(err) : resolve() );
  });
}

// --------------------------------------------------------------------------
// --- Child Process
// --------------------------------------------------------------------------

const childprocess = {} ;

atExitForEach(childprocess,(process) => process.kill());

function stdSpec( spec , isOutput ) {
  switch(spec) {
  case undefined:
    return { io: isOutput ? 'pipe' : 'ignore' };
  case null:
  case 'null':
  case 'ignore':
    return { io: 'ignore' };
  case 'pipe':
    return { io: 'pipe' };
  default:
    const fd = spec.path ? fs.openSync( spec.path , spec.mode || (isOutput ? 'w' : 'r') ) : undefined ;
    return (isOutput && spec.pipe) ? { io: 'pipe', fd } : { io: fd } ;
  }
}

function pipeTee( std , fd )
{
  if (!fd) return;
  const out = fs.createWriteStream(null,{ fd, encoding: 'UTF-8' });
  out.on('error',(err) => {
    console.warn("[Dome] can not pipe:",err);
    std.unpipe(out);
  });
  std.pipe(out);
}

/**
   @summary Spawn a child process.
   @param {string} command - the command to spawn
   @param {string[]} [args] - the command arguments
   @param {object} [options] - spawning options (see above)
   @return {Promise<ChildProcess>} unless rejected, returns a process
   object to interact with the spawned command
   @description
Based on [Node `child_process.spawn`](https://nodejs.org/dist/latest-v12.x/docs/api/child_process.html#child_process_child_process_spawn_command_args_options). The promised process object is a regular [Node `ChildProcess`](https://nodejs.org/api/child_process.html#child_process_class_childprocess) object, for which we recall the main useful methods below:

 - `child.on('exit',(code) => {...})` emitted event when the process is terminated
 - `child.on('close',(code) => {...})` emitted event when the process is fully terminated (all pipes closed)
 - `child.on('message',(...data) => {...})` emitted from the _forked_ process (if applicable)
 - `child.stdout.on('data',(text) => {...})` emitted when the process writes on piped stdout (receives `UTF-8` strings)
 - `child.stderr.on('data',(text) => {...})` emitted when the process writes on piped stderr (receives `UTF-8` strings)
 - `child.kill()` sends a `'SIGTERM'` unix message to the process

Options is an object similar to the original Node options, with small adaptations.
The possible option fields are described as follows:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cwd`  | `string` | `process.cmd` | Working directory for the command |
| `env`  | `object` | `{}` | _additional_ environment variables |
| `stdin` | _stdio_ | `'ignored'` | Standard input stream |
| `stdout` | _stdio_ | `'pipe'` | Standard output stream |
| `stderr` | _stdio_ | `'pipe'` | Standard error stream |
| `fork` | `boolean` | `false` | Fork a Node-child process |

Environment variables are _added_ to the default `process.env` environment.

Input and output streams are defined according to the following table:

| _stdio_  | Description |
|----------|-------------|
| `'pipe'` | Accessible _via_ the promised child-process object |
| `'ignored'` | Connected to `/dev/null` |
| `{ path[,mode][,pipe] }` | Connected to file `path` |

All pipes have their encoding set to `UTF-8`,
hence all callbacks on process events will receive natural strings instead of raw byte buffers.

When specifying a file for a process standard stream, an optional mode can be specified.
Default is `'r'` for input streams and `'w'` for output ones.
If option `pipe:true` is provided (output streams only), the output of the process is
also piped through the Process object. The file-path is relative to the current working directory
of the _application_, not be confused with the `cwd` option of the spawned command.

When the `fork` flag is set, the child process is spawned using
[Node `child_process.fork`](https://nodejs.org/dist/latest-v12.x/docs/api/child_process.html#child_process_child_process_fork_modulepath_args_options). This enables Node inter-process communication _via_ the
`process.send()` and `process.on('message')` methods of the child process object.
*/

export function spawn(command,args,options) {
  return new Promise((resolve,reject) => {

    const cwd = options ? options.cwd : undefined ;
    const env = options && options.env ? Object.assign( {} , process.env , options.env ) : undefined ;
    const stdin = stdSpec( options && options.stdin , false );
    const stdout = stdSpec( options && options.stdout , true );
    const stderr = stdSpec( options && options.stderr , true );
    const stdio = [ stdin.io , stdout.io , stderr.io ] ;
    const opt = { cwd , env , stdio , windowsHide: true };
    const fork = options && options.fork ;
    var process ;

    if (fork) {
      opt.stdio.push( 'ipc' );
      process = Exec.fork(command,args,opt);
    } else {
      process = Exec.spawn(command,args,opt);
    }

    if ( !process ) {
      throw `[Dome] Unable to create process ('${command}')`;
      return;
    }

    const pid = process.pid ;

    if ( !pid ) {
      // Must defer rejection, otherwize an uncaught exception is raised.
      process.on('error',(err) => reject(err));
      return;
    }

    childprocess[pid] = process ;
    process.on('exit',() => delete childprocess[pid]);

    const out = process.stdout ;
    const err = process.stderr ;

    if (out) {
      out.setEncoding('UTF-8');
      pipeTee( out , stdout.fd );
    }
    if (err) {
      err.setEncoding('UTF-8');
      pipeTee( err , stderr.fd );
    }

    resolve(process);
  });
}

// --------------------------------------------------------------------------
// --- Window Management
// --------------------------------------------------------------------------

const WINDOW_APPLICATION_ARGV = '--dome-application-window' ;
const WINDOW_PREFERENCES_ARGV = '--dome-preferences-window' ;

// --------------------------------------------------------------------------
// --- Only used for inter-module initialisation
// --------------------------------------------------------------------------

export default {
  SET_COMMAND,
  WINDOW_APPLICATION_ARGV,
  WINDOW_PREFERENCES_ARGV
};

// --------------------------------------------------------------------------
