// --------------------------------------------------------------------------
// --- Text Documents
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/text/buffers
*/

import Emitter from 'events';
import CodeMirror from 'codemirror/lib/codemirror.js';

export type Range = { from: CodeMirror.Position, to: CodeMirror.Position };

export interface Decorator {
  /** @return a className to apply on markers with the identifier. */
  (id: string): string | undefined;
}

export interface TextMarkerProxy {
  clear(): void;
  changed(): void;
  find(): Range | undefined;
}

export interface MarkerProps extends CodeMirror.TextMarkerOptions {
  id?: string;
  hover?: boolean;
  className?: string;
}

/**
   Text with tags.

   In the object form, a text marker is created with given attributes
   and text.
 */
export type MarkedText = undefined | null | string
  | MarkedText[]
  | MarkerProps & { text: MarkedText }
  ;

// --------------------------------------------------------------------------
// --- Markers Proxy
// --------------------------------------------------------------------------

class Proxy implements TextMarkerProxy {
  private marker?: CodeMirror.TextMarker;
  clear() { this.marker?.clear(); }
  changed() { this.marker?.changed(); }
  find() { return this.marker?.find(); }
  _link(marker: CodeMirror.TextMarker) { this.marker = marker; }
}

interface StackedMarker {
  id?: string;
  hover?: boolean;
  className?: string;
  options: CodeMirror.TextMarkerOptions;
  start: CodeMirror.Position;
  proxy: Proxy;
}

export interface CSSMarker {
  /** Hover class `'dome-xHover-nnn'` */
  classNameId: string;
  /** Marker id */
  id: string | undefined;
  /** Hovered marker */
  hover: boolean;
  /** Size in character */
  length: number;
}

// --------------------------------------------------------------------------
// --- Buffer
// --------------------------------------------------------------------------

export interface RichTextBufferProps {

  /** CodeMirror [mode](https://codemirror.net/mode/index.html) specification. */
  mode?: any;

  /** Maximum number of lines in the buffer. */
  maxlines?: number;

}

/**
   Rich Text Content and State.

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

  private _doc: CodeMirror.Doc;
  private _maxlines: number = 10000;
  private _operations: number = 0; // cm started operations
  private _editors: CodeMirror.Editor[] = [];
  private _stacked: StackedMarker[] = [];

  // Indexed by CSS property dome-xHover-nnnn
  private _mhovers = new Map<string, CSSMarker>();

  // Indexed by marker user identifier
  private _markers = new Map<string, CodeMirror.TextMarker[]>();

  private _decorator?: Decorator;
  private _edited = false;
  private _focused = false;
  private _markid = 0;

  constructor(props: RichTextBufferProps = {}) {
    super();
    const { mode, maxlines } = props;
    this._doc = new CodeMirror.Doc('', mode);
    this.setMaxlines(maxlines);
    this.setEdited = this.setEdited.bind(this);
    this.setFocused = this.setFocused.bind(this);
    this.clear = this.clear.bind(this);
    this.append = this.append.bind(this);
    this.setValue = this.setValue.bind(this);
    this.getValue = this.getValue.bind(this);
    this.updateDecorations = this.updateDecorations.bind(this);
    this.onChange = this.onChange.bind(this);
    this.log = this.log.bind(this);
  }

  /**
     Internal CodeMirror
     [document](https://codemirror.net/doc/manual.html#api_doc) instance.
  */
  getDoc(): CodeMirror.Doc { return this._doc; }

  // --------------------------------------------------------------------------
  // --- Buffer Manipulation
  // --------------------------------------------------------------------------

  /** Clear buffer contents and resets _edited_ state. */
  clear() { this.setValue(''); }

  /**
     Writes in the buffer. All parameters are converted to string and joined
     with spaces.  The generated change event has origin `'buffer'` and it does
     not modifies the _edited_ internal state.
  */
  append(...values: any[]) {
    if (values.length > 0) {
      const doc = this._doc;
      const start = doc.posFromIndex(Infinity);
      const text = values.join(' ');
      doc.replaceRange(text, start, undefined, 'buffer');
      this.shrink();
    }
  }

  /**
     Starts a new line in the buffer. If the current buffer content does not
     finish at the beginning of a fresh line, inserts a newline character.
  */
  flushline() {
    const doc = this._doc;
    const start = doc.posFromIndex(Infinity);
    if (start.ch > 0) doc.replaceRange('\n', start, undefined, 'flush');
  }

  /**
     Appends with newline and auto-scrolling. This is a short-cut to
     `flushline()` followed by `append(...value,'\n')` and `scroll()`.
   */
  log(...values: any[]) {
    this.flushline();
    this.append(...values, '\n');
    this.scroll();
  }

  /**
     Replace all textual content with the given string.
     Also remove all markers.
   */
  setValue(txt = '') {
    this._doc.setValue(txt);
    this._edited = false;
    this._stacked = [];
    this._focused = false;
    this._markid = 0;
    this._mhovers.clear();
    this._markers.clear();
  }

  /** Return the textual contents of the buffer. */
  getValue() { return this._doc.getValue(); }

  /**
     Opens a text marker.

     Opens a text marker at the current (end) position in the buffer.

     The text marker is stacked and would be actually created on the matching
     [[closeTextMarker]] call. It will be applied to the full range of text
     inserted between its associated [[openTextMarker]] and [[closeTextMarker]]
     calls.

     The returned text marker is actually a _proxy_ to the text marker that will be
     eventually created by [[closeTextMarker]]. Its methods are automatically
     forwarded to the actual `CodeMirror.TextMarker`
     instance, once created.  Hence, you can safely invoke these methods on either
     the _proxy_ or the _final_ text marker at your convenience.
  */

  openTextMarker(props: MarkerProps): TextMarkerProxy {
    const { id, hover, className, ...options } = props;
    const start = this._doc.posFromIndex(Infinity);
    const proxy = new Proxy();
    this._stacked.push({ start, id, hover, className, options, proxy });
    return proxy;
  }

  /**
     Closes the last opened marker.

     Returns the (actual) [text marker]
     (https://codemirror.net/doc/manual.html#api_marker) ; the proxy
     returned by the corresponding call to [[openTextMarker]] is automatically
     bound to the actual one.

  */
  closeTextMarker(): CodeMirror.TextMarker | undefined {
    const tag = this._stacked.pop();
    const doc = this._doc;
    if (tag) {
      const { id, hover, start, className } = tag;
      const stop = doc.posFromIndex(Infinity);
      var markerId;
      if (id || hover) {
        markerId = 'dome-xHover-' + (this._markid++);
        const p = doc.indexFromPos(start);
        const q = doc.indexFromPos(stop);
        const cmark = {
          id,
          classNameId: markerId,
          hover: hover ?? (id !== undefined),
          length: q - p,
        };
        this._mhovers.set(markerId, cmark);
      }
      const fullClassName = [
        'dome-xMarked',
        id && ('dome-xMark-' + id),
        markerId,
        className,
      ].filter((s) => !!s).join(' ');
      const options = {
        shared: true,
        className: fullClassName,
        ...tag.options,
      };
      const marker = doc.markText(start, stop, options);
      if (id) {
        const markers = this._markers;
        const ms = markers.get(id);
        if (ms === undefined)
          markers.set(id, [marker]);
        else
          ms.push(marker);
      }
      tag.proxy._link(marker);
      this.shrink();
      return marker;
    } else
      return undefined;
  }

  /** Lookup for the text markers associated with a marker identifier. */
  findTextMarker(id: string): CodeMirror.TextMarker[] {
    return this._markers.get(id) ?? [];
  }

  /** Lopokup for a hover class. */
  findHover(className: string): CSSMarker | undefined {
    return this._mhovers.get(className);
  }

  // --------------------------------------------------------------------------
  // --- Highlighter
  // --------------------------------------------------------------------------

  /**
     Define highlighter.

     @param fn - highlighter, `fn(id)` shall return a className to apply
     on text markers with the provided identifier.
  */
  setDecorator(fn: Decorator) {
    this._decorator = fn;
    this.emit('decorated');
  }

  /**
     Current highlighter.
   */
  getDecorator() { return this._decorator; }

  /**
     Rehighlight document.

     Emits the `'decorated'` event to make editors
     updating the decorations of identified text markers.

     This can be used when decoration shall be re-computed,
     even if the decoration function was not modified.

     The method is bound to `this`.
  */
  updateDecorations() { this.emit('decorated'); }

  // --------------------------------------------------------------------------
  // --- Edited State
  // --------------------------------------------------------------------------

  /**
     Set edited state.

     The method is automatically invoked by editor views when the user actually
     edit the document.  The state is _not_ modified when modifying the document
     from buffer's own methods, _eg._ `append()` and `clear()`.

     The method fires the `'edited'` event on modifications.  This method is
     bound to `this`, hence `this.setEdited` can be used as a valid callback
     function.

     @param state - the new edited state (defaults to `true`).
  */
  setEdited(state = true) {
    if (state !== this._edited) {
      this._edited = state;
      this.emit('edited', state);
    }
  }

  /**
     Set focused state.

     The method is automatically invoked by editor views when they gain or lose
     focus or when the user actually interact with the view,
     eg. mouse-scrolling, edition, cursor move, etc.  The escape key `ESC`
     explicitly relax the _focused_ state, although the editor view might
     actually keep the _focus_.

     When a buffer is _focused_, shrinking and auto-scrolling are temporarily
     deactivated to avoid confusing user's experience.

     The method fires `'focused'` events on modifications. This method is bound
     to `this`, hence `this.setEdited` can be used as a valid callback function.

     @param focus - the new focused state (defaults to `true`).
  */
  setFocused(state = true) {
    if (state !== this._focused) {
      this._focused = state;
      this.emit('focused', state);
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
     Set (or unset) the maximum number of lines.

     By default, the maximum number of lines is set to `10,000` to avoid
     unwanted memory leaks. Setting `null`, `0` of any negative value cancel the
     management of maximum number of lines.

     Although CodeMirror is powerfull enough to manage huge buffers, you should
     turn this limit _off_ with care.
  */
  setMaxlines(maxlines = 10000) {
    this._maxlines = maxlines > 0 ? 1 + maxlines : 0;
    this.shrink();
  }

  /**
     Remove head lines to fits into maximum lines.

     Shrinking is activated when `maxlines` property is set to a strictly
     positive number. When the number of lines in the buffer is larger than the
     max, buffer is trimmed by removing extra _heading_ lines.

     When the buffer if _focused_ or when there are still opened text marks
     pending, shrinking is automatically postponed until focus is lost and all
     pending marks have been closed.
   */
  shrink() {
    if (
      !this._operations
      && !this._focused
      && this._maxlines > 0
      && this._stacked.length == 0
    ) {
      const lines = this._doc.lineCount();
      if (lines > this._maxlines) {
        const p = this._doc.firstLine();
        const q = p + lines - this._maxlines;
        this._doc.replaceRange(
          '',
          { line: p, ch: 0 },
          { line: q, ch: 0 },
          'buffer'
        );
      }
    }
  }

  /**
     Requires all connected views to scroll to the
     specified line or identified marker.

     @param position -
     defaults to the end of buffer (when not focused).
  */
  scroll(position?: string | number): void {
    if (position === undefined) {
      if (!this._focused)
        this.emit('scroll', this._doc.lastLine());
    } else if (typeof position === 'number') {
      this.emit('scroll', position);
    } else if (typeof position === 'string') {
      var line = Infinity;
      this.findTextMarker(position).forEach((tm) => {
        const rg = tm.find();
        const ln = rg.from.line;
        if (ln < line) line = ln;
      });
      if (line !== Infinity)
        this.emit('scroll', line);
    }
  }

  // --------------------------------------------------------------------------
  // --- Document Linking
  // --------------------------------------------------------------------------

  private onChange(
    _editor: CodeMirror.Editor,
    change: CodeMirror.EditorChangeLinkedList
  ) {
    if (change.origin !== 'buffer') this.setEdited(true);
    this.emit('change');
  }

  /**
     Binds this buffer to a CodeMirror instance.

     Uses CodeMirror linked documents to allow several CodeMirror instances to
     be linked to the same buffer. Can be released with [[unlink]].

     @param cm - code mirror instance to link this document in.
  */
  link(cm: CodeMirror.Editor) {
    const newDoc = this._doc.linkedDoc({ sharedHist: true, mode: undefined });
    cm.swapDoc(newDoc);
    cm.on('change', this.onChange);
    this._editors.push(cm);
    if (this._operations > 0) cm.startOperation();
  }

  /**
     Release a linked CodeMirror document previously linked with [[link]].
     @param cm - the code mirror instance to unlink
  */
  unlink(cm: CodeMirror.Editor) {
    const oldDoc = cm.getDoc();
    this._doc.unlinkDoc(oldDoc);
    this._editors = this._editors.filter((cm0) => {
      if (cm === cm0) {
        cm.off('change', this.onChange);
        return false;
      }
      return true;
    });
    if (this._operations > 0) cm.endOperation();
  }

  /**
     Iterates over each linked CodeMirror instances

     The operation `fn` is performed on each code mirror
     instance currently linked to this buffer.
   */
  forEach(fn: (editor: CodeMirror.Editor) => void) {
    this._editors.forEach(fn);
  };

  // --------------------------------------------------------------------------
  // --- Stacked Operations
  // --------------------------------------------------------------------------

  /**
     Batch heavy operations on editors

     Uses code mirror `cm.startOperation()` and `cm.sendOperation()` on all
     linked editors to batch the updating operations performed on the
     buffer. The batched updates can run asynchronously.

     @param fn - function performing the operations (can return a promise)
     @returns the promised job
  */
  operation<A = void>(job: () => Promise<A> | A): Promise<A> {

    // Protect each start/end call against error
    const forEachEditor = (fn: (cm: CodeMirror.Editor) => void) => {
      this._editors.forEach((cm) => {
        try { fn(cm); } catch (e) { console.error('[Dome.text.buffers]', e); }
      });
    };

    // Invariant: this._operations is the number of batched job still running
    // Invariant: when pending job are running, all linked this._editors are started
    // Second invariant is also maintained by link and unlink methods

    const startOperation = () => {
      this._operations++;
      if (this._operations == 1)
        forEachEditor((cm) => cm.startOperation());
    };

    const endOperation = () => {
      this._operations--;
      if (this._operations == 0) {
        forEachEditor((cm) => cm.endOperation());
        this.shrink();
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
     Print text containing tags into buffer.
     It is recommended to call this method within an [[operation]].

     @param implicitTag - when true,
     uses the first element of arrays as an marker identifier for the
     the rest of text. This implicit tag policy is recursively applied to
     sub-arrays.
  */
  printTextWithTags(contents: MarkedText, implicitTag = false) {
    if (contents !== undefined && contents !== null) {
      if (Array.isArray(contents)) {
        var marker = false;
        if (implicitTag) {
          const id = contents.shift();
          if (typeof id === 'object') {
            contents.unshift(id);
          } else {
            this.openTextMarker({ id });
            marker = true;
          }
        }
        contents.forEach((txt) => this.printTextWithTags(txt, implicitTag));
        if (marker) this.closeTextMarker();
      } else if (typeof contents === 'object') {
        const { text, ...tag } = contents;
        this.openTextMarker(tag);
        this.printTextWithTags(text, implicitTag);
        this.closeTextMarker();
      } else if (typeof contents === 'string') {
        this.append(contents);
      } else {
        console.error('[Dome.buffers] unexpected text', contents);
      }
    }
  }

}

// --------------------------------------------------------------------------
