// --------------------------------------------------------------------------
// --- Text Documents
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/text/buffers
*/

import Emitter from 'events' ;
import CodeMirror from 'codemirror/lib/codemirror.js' ;

const combineClass = (a,b) => a ? (b ? (a + " " + b) : a) : b ;

// --------------------------------------------------------------------------
// --- Marker Proxy
// --------------------------------------------------------------------------

class Proxy {

  clear() { this.marker && this.marker.clear(); }
  changed() { this.marker && this.marker.changed(); }
  find() { return this.marker && this.marker.find(); }
  _link(marker) { this.marker = marker ; }

}

// --------------------------------------------------------------------------
// --- Buffer
// --------------------------------------------------------------------------

/**
   @summary Rich Text Content and State.
   @description

   A buffer encapsulate a CodeMirror document instance inside an standard
   Node event emitter. CodeMirror signals are automatically linked back to
   the event emitter (on a lazy basis).

   The `maxlines` will control the maximum number of lines kept in the buffer.
   By default, it is set to `10000`, but you can use `null`, `0` or any negative
   value to disable this behavior. See also `this.setMaxlines()` method.

   Additionnaly, a Buffer maintains an _edited_ state internally that can
   be manually updated, and that is automatically set to `true` when the
   underlying CodeMirror document is changed. It is associated to an `'edited'`
   event of the buffer, and can be used to manage the « Saved » / « Not-Saved »
   state of an editor, for instance.

   Typically, a sequence of changed events would fire a unique `'edited'` buffer
   event, untill `setEdited(false)` is invoked. The `clear()` method also resets
   the _edited_ state to `false`, but sill emit an `'edited'` event if the
   buffer was not empty.

   Buffers can also be updated programmatically by various methods. In addition to
   specified CodeMirror modes, you can also attach text markers programmatically with
   a push/pop API.

   Text markers can be associated with an identifier, that can be used for
   dynamic highlighting, called Decorations. Decorations are class names that
   add styling attributes upon the current mode. Typically, consider only using
   background colors, underlines and/or strike-through for decorations, since
   font styles and colors are likely to be managed by CodeMirror modes, unless
   you know exactly what your are doing.

   The `setDecorator` method can be used to set or update
   the highlighting function that computes the decoration of a text marker
   from its identifier. When the decorations may have change, you shall either
   set again the highlighting function with a call to `setDecorator()` or call
   the `updateDecorations()` method. This also triggers the `'decorated'` event.

 */

export class RichTextBuffer extends Emitter {

  /**
     @param {object} [props] - Constructor properties (see below)
     @param {string | object} [props.mode] - CodeMirror [mode](https://codemirror.net/mode/index.html) specification
     @param {number} [props.maxlines] - Maximum number of lines in the buffer
  */
  constructor(props = {}) {
    super();
    const { mode , maxlines } = props ;
    this._doc = new CodeMirror.Doc('',mode);
    this._operations = 0 ;
    this._editors = [] ;
    this._stacked = [] ;
    this._edited = false ;
    this._focused = false ;
    this._markid = 0 ;
    this._markers = {} ;
    this._decorator = undefined ;
    this.setMaxlines(maxlines);
    this.setEdited = this.setEdited.bind(this);
    this.setFocused = this.setFocused.bind(this);
    this.clear = this.clear.bind(this);
    this.append = this.append.bind(this);
    this.setValue = this.setValue.bind(this);
    this.getValue = this.getValue.bind(this);
    this.log = this.log.bind(this);
    this._doc.on('change', ( _target , { origin } ) => {
      if (origin !== 'buffer') this.setEdited(true);
      this.emit('change');
    });
  }

  /**
     @summary CodeMirror document instance.
     @return {CodeMirror.Doc} internal [document](https://codemirror.net/doc/manual.html#api_doc)
     @description
     Returns the `CodeMirror.Doc` instance holding the buffer contents.
     This can be used for further customization.
     <p>
     This document will never be bound to a `CodeMirror` instance. Instead, `Text` views
     will use _linked_ documents to the buffer one. This allows for several views to
     share the same document (and history).
  */
  getDoc() { return this._doc; }

  // --------------------------------------------------------------------------
  // --- Buffer Manipulation
  // --------------------------------------------------------------------------

  /** Clear buffer contents and resets _edited_ state. */
  clear() { this.setValue(''); }

  /**
     @summary Writes in the buffer.
     @param {any} [value] - content to append in the buffer
     @description
     Appends textual contents to the end of the buffer.
     All parameters are converted to string and joined with spaces.
     The generated change event has origin `'buffer'` and it does not
     modifies the _edited_ internal state.
  */
  append(...value) {
    if (value.length > 0) {
      const doc = this._doc ;
      const from = doc.posFromIndex(Infinity);
      const text = value.join(' ');
      doc.replaceRange(text,from,undefined,'buffer');
      this.shrink();
    }
  }

  /**
     @summary Starts a new line in the buffer.
     @description
     If the current buffer content does not finish at the beginning of a fresh line,
     inserts a newline character.
  */
  flushline() {
    const doc = this._doc ;
    const from = doc.posFromIndex(Infinity);
    if (from.ch > 0) doc.replaceRange('\n',from,undefined,'flush');
  }

  /**
     @summary Appends with newline and auto-scrolling.
     @param {any} [value] - content to append in the buffer
     @description
     This is a short-cut to `flushline()` followed by `append(...value,'\n')` and `scroll()`.
   */
  log(...value) {
    this.flushline();
    this.append(...value,'\n');
    this.scroll();
  }

  /**
     @summary Replace textual content with the given value.
     @param {string} [txt] - new text content
     @description
     Also remove all markers.
   */
  setValue(txt='') {
    this._doc.setValue(txt);
    this._edited = false;
    this._stacked = [] ;
    this._focused = false ;
    this._markid = 0 ;
    this._markers = {} ;
  }

  /**
     @summary Return textual content.
     @return {string}
  */
  getValue() { return this._doc.getValue(); }

  /**
     @summary Opens a text marker.
     @param {object} options - CodeMirror
       [text marker](https://codemirror.net/doc/manual.html#api_marker) options
     @return {CodeMirror.TextMarker} the associated
       [text marker](https://codemirror.net/doc/manual.html#api_marker) (proxy)
     @description
Opens a text marker at the current (end) position in the buffer.

The text marker is stacked and would be actually created on the
matching `closeTextMarker()` call. It will be applied to the full range of text
inserted between its associated `openTextMarker()` and `closeTextMarker()` calls.

The returned text marker is actually a _proxy_ to the text marker that
will be eventually created by `closeTextMarker()`. Its methods (`find`, `clear` and `changed`)
are automatically forwarded to the actual `CodeMirror.TextMarker` instance, once created.
Hence, you can safely invoke these methods on either the _proxy_ or the _final_
text marker at your convenience.

Additionnaly to standard `CodeMirror.TextMarker` options, you may also the
following Dome specific ones:
- `id: string` assigns an identifier to the marker (expected to be unique) ;
- `hover: boolean` makes the text-marker highlighted on mouse-hover ; this is compatible with
  _nested_ markers, which is not possible with CSS `:hover` pseudo selectors ; defaults to `true` for
  identified text markers and `false` otherwize.
*/

  openTextMarker( { id , hover, className, ...options } ) {
    const from = this._doc.posFromIndex(Infinity);
    const proxy = new Proxy();
    this._stacked.push( { from , id , hover, className, options , proxy } );
    return proxy ;
  }

  /**
     @summary Close last opened marker.
     @return {CodeMirror.TextMarker} the (actual)
     [text marker](https://codemirror.net/doc/manual.html#api_marker)
     @description
     Closes the lastly opened text marker with `openTextMarker()`.
     The method returns the _actual_
     text marker ; the _proxy_ text marker provided by the corresponding
     call to `openTextMarker()` is automatically bound to the actual one.
  */
  closeTextMarker() {
    const tag = this._stacked.pop();
    if (tag) {
      const { id, hover, from } = tag ;
      const to = this._doc.posFromIndex(Infinity);
      var classNameWithId ;
      var tagid ;
      if ( id || hover ) {
        const mhover = hover !== undefined ? hover : (id !== undefined) ;
        const cid = id ? 'dome-xMark-' + id : ('dome-xHover-' + (++this._markid)) ;
        const p = this._doc.indexFromPos(from);
        const q = this._doc.indexFromPos(to);
        const m = this._markers[cid];
        if (m) console.warn('[Dome.text.buffers] duplicate marker',id);
        tagid = this._markers[cid] = { id, hover:mhover, classNameId:cid, length: q-p } ;
        classNameWithId = id ? "dome-xMarked " + cid : cid ;
      }
      const className = combineClass( tag.className, classNameWithId );
      const options = Object.assign( { shared:true, className } , tag.options );
      const marker = this._doc.markText( from , to , options );
      tag.proxy._link(marker);
      if (tagid) tagid.marker = marker ;
      this.shrink();
      return marker ;
    } else
      return undefined ;
  }

  /**
     @description Lookup a text marker
     @param {string} id - requested identifier
     @return {CodeMirror.TextMarker} the identified text marker, or `undefined` if not found.
  */
  findTextMarker(id) {
    if (id) {
      const m = this._markers['dome-xMark-' + id] ;
      if (m) return m.marker ;
    }
    return undefined;
  }

  /**
     @summary Lookup a hover class.
     @param {string} className - a class name, possibly identifying a hover element
     @return {hover} the associated hovered element `{id, classNameId, length}`, or
     `undefined` if the provided `className` does not identify any such element.
   */
  findHover(name) { return this._markers[name]; }

  // --------------------------------------------------------------------------
  // --- Highlighter
  // --------------------------------------------------------------------------

  /**
     @summary Define highlighter.
     @param {function} highlighter - the function that computes
     the decoration class of a marker id.
  */
  setDecorator(f) { this._decorator = f ; this.emit('decorated'); }

  /**
     @summary Current highlighter.
     @return {function} the current highlighting function
   */
  getDecorator() { return this._decorator ; }

  /**
     @summary Rehighlight document.
     @description
     Emits the `'decorated'` event to make editors
     updating the decorations of identified text markers.
  */
  updateDecorations() { this.emit('decorated'); }

  // --------------------------------------------------------------------------
  // --- Edited State
  // --------------------------------------------------------------------------

  /**
     @summary Set edited state.
     @param {boolean} [state] - the new edited state (defaults to `true`).
     @description

Set the _edited_ internal state. The method is automatically invoked by editor
views when the user actually edit the document.  The state is _not_ modified
when modifying the document from buffer's own methods, _eg._ `append()` and
`clear()`.

The method fires the `'edited'` event on modifications.  This method is bound to
`this`, hence `this.setEdited` can be used as a valid callback function.
  */
  setEdited(state = true) {
    if ( state !== this._edited ) {
      this._edited = state ;
      this.emit('edited',state);
    }
  }

  /**
     @summary Set focused state.
     @param {boolean} [focus] - the new focused state (defaults to `true`).
     @description

Set the _focused_ internal state. The method is automatically invoked by editor
views when they gain or lose focus or when the user actually interact with the
view, eg. mouse-scrolling, edition, cursor move, etc.  The escape key `ESC`
explicitly relax the _focused_ state, although the editor view might actually
keep the _focus_.

When a buffer is _focused_, shrinking and auto-scrolling are temporarily deactivated
to avoid confusing user's experience.

The method fires `'focused'` events on modifications. This method is bound to
`this`, hence `this.setEdited` can be used as a valid callback function.
  */
  setFocused(state = true) {
    if ( state !== this._focused ) {
      this._focused = state ;
      this.emit('focused',state);
      this.shrink();
    }
  }

  /** Returns the current _edited_ state. */
  isEdited() { return this._edited; }

  /** Returns the current _focused_ state. */
  isFocused() { return this._focused; }

  // --------------------------------------------------------------------------
  // --- Document Scrolling
  // --------------------------------------------------------------------------

  /**
     @summary Set (or unset) the maximum number of lines.
     @param {number} [maxlines] - maximum number of lines
     @description

By default, the maximum number of lines is set to `10,000` to avoid
unwanted memory leaks. Setting `null`, `0` of any negative value cancel
the management of maximum number of lines.

Although CodeMirror is powerfull enough to manage huge buffers,
you should turn this limit _off_ with care.
  */
  setMaxlines(maxlines=10000) {
    this._maxlines = maxlines > 0 ? 1 + maxlines : 0 ;
    this.shrink();
  }

  /**
      @summary Remove head lines to fits into maximum lines.
      @description

Shrinking is activated when `maxlines` property is set to a strictly
positive number. When the number of lines in the buffer is larger than
the max, buffer is trimmed by removing extra _heading_ lines.

When the buffer if _focused_ or when there are still opened text marks pending,
shrinking is automatically postponed until focus is lost and all pending marks
have been closed.
   */
  shrink()
  {
    if (!this._focused && this._maxlines > 0 && this._stacked.length == 0) {
        const lines = this._doc.lineCount();
        if (lines > this._maxlines) {
          const p = this._doc.firstLine();
          const q = p + lines - this._maxlines ;
          this._doc.replaceRange('',{line:p,ch:0},{line:q,ch:0},'buffer');
        }
    }
  }

  /**
     @summary Requires all connected views to scroll to the specified position in the buffer.
     @param {...any} [args] - the position or range to be made visible
     @description
Typical usage:
 - `scroll()` to the end of buffer
 - `scroll(id)` to identified marked `id`;
 - `scroll(p)` a position: line number or `{line,ch?}` CodeMirror position;
 - `scroll(p,q)` a range of two positions (like above);
 - `scroll({from,to})` an object range of two positions (like above).

When the buffer is _focused_, programmatic auto-scrolling with `scroll()`
is blocked.
   */
  scroll(a,b) {
    switch(typeof(a)) {
    case 'undefined':
      if (this._focused) return;
      this.emit('scroll',{line:this._doc.lastLine(),ch:0});
      break;
    case 'string':
      const tm = this.findTextMarker(a);
      const rg = tm && tm.find();
      if (rg) this.emit('scroll',rg);
      break;
    default:
      const isLineCh = (a) => (
        a && Number.isInteger(a.line)
          && (a.ch === undefined || Number.isInteger(a.ch))
      );
      const getPos = (a) => (
        Number.isInteger(a) ? { line: a, ch:0 } :
        isLineCh(a) ? a : console.warn('[Dome.text.buffers] can not scroll to',a)
      );
      var from,to ;
      if (a && a.from && a.to) {
        from = getPos(a.from);
        to = getPos(a.to);
      } else {
        from = getPos(a);
        to = b && getPos(b);
      }
      if (from && to) this.emit('scroll',{from,to});
      else if (from) this.emit('scroll',from);
    }
  }

  // --------------------------------------------------------------------------
  // --- Document Linking
  // --------------------------------------------------------------------------

  /**
     @summary Bind this buffer to a CodeMirror instance.
     @param {CodeMirror} cm - code mirror instance to link this document in.
     @description
     Uses CodeMirror linked documents to allow several CodeMirror instances to be linked
     to the same buffer.
  */
  link(cm) {
    const newDoc = this._doc.linkedDoc( { sharedHist: true } );
    cm.swapDoc( newDoc );
    this._editors.push(cm);
    if (this._operations > 0) cm.startOperation();
  }

  /**
     @summary Release a linked CodeMirror document.
     @param {CodeMirror} cm - the code mirror instance to unlink
     @param {Document} previous document of the instance.
     @description
     Unlinks a CodeMirror document previously linked by `link(cm)`.
  */
  unlink(cm) {
    const oldDoc = cm.getDoc();
    this._doc.unlinkDoc( oldDoc );
    this._editors = this._editors.filter((cm0) => cm0 !== cm);
    if (this._operations > 0) cm.endOperation();
  }

  /**
     @summary Iterates over each linked CodeMirror instances
     @description
     The operation `fn` is performed on each code mirror
     instance currently linked to this buffer.
   */
  forEach(fn) {
    this._editors.forEach(fn);
  };

  // --------------------------------------------------------------------------
  // --- Stacked Operations
  // --------------------------------------------------------------------------

  /**
     @summary Batch heavy operations on editors
     @param {function} job - a function performing the operations (can return a promise)
     @return {promise} the promised job
     @description
     Uses code mirror `cm.startOperation()` and `cm.sendOperation()` on all
     linked editors to batch the updating operations performed on the
     buffer. The batched updates can run asynchronously.
  */
  operation(job) {

    // Protect each start/end call against error
    const forEachEditor = (fn) => {
      this._editors.forEach((cm) => {
        try { fn(cm); } catch(e) { console.error('[Dome.text.buffers]',e); }
      });
    };

    // Invariant: this._operations is the number of batched job still running
    // Invariant: when pending job are running, all linked this._editors are started
    // Second invariant is also maintained by link and unlink methods

    const startOperation = () => {
      this._operations ++;
      if (this._operations == 1)
        forEachEditor((cm) => cm.startOperation());
    };

    const endOperation = () => {
      this._operations --;
      if (this._operations == 0) {
        forEachEditor((cm) => cm.endOperation());
      }
    };

    return Promise.resolve()
      .then(startOperation)
      .then(job)
      .finally(endOperation);
  }

  // --------------------------------------------------------------------------
  // --- Print Utilities
  // --------------------------------------------------------------------------

  /**
     @summary Print text containing tags into buffer (bound to `this`).
     @param {string|string[]} text - Text to print.
     @param {object} options - CodeMirror
       [text marker](https://codemirror.net/doc/manual.html#api_marker) options.
  */
  printTextWithTags(text = '', options = {}) {
    if (Array.isArray(text)) {
      const tag = text.shift();
      if (tag !== '') {
        const markerOptions = { id: tag, ...options };
        this.openTextMarker(markerOptions);
      }
      text.forEach((txt) => this.printTextWithTags(txt, options));
      if (tag !== '') {
        this.closeTextMarker();
      }
    } else if (typeof text === 'string') {
      this.append(text);
    } else if (text !== null) {
      console.error('[Dome.buffers] Unexpected text', text);
    }
  }

}

// --------------------------------------------------------------------------
