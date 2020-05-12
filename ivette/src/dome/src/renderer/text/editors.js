// --------------------------------------------------------------------------
// --- Text Documents
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/text/editors
*/

import _ from 'lodash' ;
import React from 'react' ;
import * as Dome from 'dome' ;
import CodeMirror from 'codemirror/lib/codemirror.js' ;

import './style.css' ;
import 'codemirror/lib/codemirror.css' ;

const CSS_HOVERED = 'dome-xText-hover' ;
const CSS_SELECTED = 'dome-xText-select' ;

// --------------------------------------------------------------------------
// --- Text View
// --------------------------------------------------------------------------

/**
   @class
   @summary Rich Text Editor.
   @property {Buffer} buffer - associated Buffer holding the text content
   @property {string} className - additional class name(s)
   @property {object} style - additional CSS style
   @property {number} fontSize - editor font-size
   @property {string} selection - currently selected markder identifier
   @property {function} onSelection - callback used when an identified marker is clicked
   @property {function} onContextMenu - selection callback on right-click
   @property {object} [...options] - additional CodeMirror
      [configuration](https://codemirror.net/doc/manual.html#config) properties
   @description

   A component rendering the content of a text buffer, that shall be instances
   of the `Buffer` base class.

   The view is based on a [CodeMirror](https://codemirror.net) component linked with
   the internal Code Mirror Document from the associated buffer.

   Multiple views might share the same buffer as source content. The buffer will be
   kept in sync with all its linked views.

   The Text component never update its mounted NODE element, however, all property
   modifications (including buffer) are propagated to the internal CodeMirror instance.
   Undefined properties are set (or reset) to the CodeMirror defaults.

   ##### Themes

   The CodeMirror `theme` option allow you to style your document,
   especially when using modes.
   Themes are only accessible if you load the associated CSS style sheet.
   For instance, to use the `'ambiance'` theme provided with CodeMirror, you shall
   import `'codemirror/theme/ambiance.css'` somewhere in your application.

   ##### Modes & Adds-On

   You can install modes and adds-on provided by the CodeMirror distribution by
   simply importing (once, before being used) the associated modules in your
   application.  For instance, to use the `'javascript'` mode option, you shall
   import `'codemirror/mode/javascript/javascript.js'` file in your application.

   ##### Further Customization

   You can register your own extensions directly into the global `CodeMirror`
   class instance.  However, the correct instance must be retrieved by using
   `import CodeMirror from 'codemirror/lib/codemirror.js'` ; using `from
   'codemirror'` returns a different instance of `CodeMirror` class and will
   not work.

 */

export class Text extends React.Component {

  constructor(props) {
    super(props);
    this.mountPoint = this.mountPoint.bind(this);
    this.refresh = this.refresh.bind(this);
    this.autoRefresh = this.autoRefresh.bind(this);
    this.onBlur = this.onBlur.bind(this);
    this.onFocus = this.onFocus.bind(this);
    this.onScroll = this.onScroll.bind(this);
    this.onClick = this.onClick.bind(this);
    this.onContextMenu = this.onContextMenu.bind(this);
    this.onMouseMove = this.onMouseMove.bind(this);
    this.handleKey = this.handleKey.bind(this);
    this.handleUpdate = this.handleUpdate.bind(this);
    this.handleHover = _.throttle(this.handleHover,50);
    this.handleScrollTo = this.handleScrollTo.bind(this);
    this.rootElement = undefined ;
    this.decorations = {} ;
    this.hover = undefined ;
  }

  // --------------------------------------------------------------------------
  // --- Mounting
  // --------------------------------------------------------------------------

  mountPoint(elt) {
    this.rootElement = elt ;
    if (elt) {
      // Mounting...
      const { buffer,
              selection,     /* ignored */
              onSelection,   /* ignored */
              onContextMenu, /* ignored */
              fontSize,      /* ignored */
              className,     /* ignored */
              style,         /* ignored */
              ...config } = this.props ;
      const value = buffer ? buffer.getDoc() : "" ;
      const cm = this.codeMirror = new CodeMirror(elt, { value });
      // Passing all options to constructor does not work (Cf. CodeMirror's BTS)
      for (var opt in config) cm.setOption( opt , config[opt] );
      cm.on('update',this.handleUpdate);
      cm.on('keyHandled',this.handleKey);
      buffer.on('decorated',this.handleUpdate);
      buffer.on('scroll',this.handleScrollTo);
      Dome.on('dome.update',this.refresh);
      this.refreshPolling = setInterval( this.autoRefresh, 250 );
      this.handleUpdate();
    } else {
      // Unmounting...
      const polling = this.refreshPolling ;
      if (polling) {
        clearInterval( polling );
        this.refreshPolling = undefined ;
      }
      const cm = this.codeMirror ;
      Dome.off('dome.update',this.refresh);
      const { buffer } = this.props ;
      if (cm && buffer) {
        buffer.unlinkDoc(cm.getDoc());
        buffer.off('decorated',this.handleUpdate);
        buffer.off('scroll',this.handleScrollTo);
      }
      this.codeMirror = undefined ;
    }
  }

  // --------------------------------------------------------------------------
  // --- Auto Refresh
  // --------------------------------------------------------------------------

  refresh() {
    const elt = this.rootElement ;
    const cm = this.codeMirror ;
    if (cm && elt) {
      this.currentWidth = elt.offsetWidth ;
      this.currentHeight = elt.offsetHeight ;
      this.currentParent = elt.offsetParent ;
      cm.refresh();
    }
  }

  // Polled every 250ms
  autoRefresh() {
    const elt = this.rootElement ;
    const cm = this.codeMirror ;
    if (cm && elt) {
      const eltW = elt.offsetWidth ;
      const eltH = elt.offsetHeight ;
      const eltP = elt.offsetParent ;
      if (eltW !== this.currentWidth ||
          eltH !== this.currentHeight ||
          eltP !== this.currentParent)
      {
        this.currentWidth = eltW ;
        this.currentHeight = eltH ;
        this.currentParent = eltP ;
        cm.refresh();
      }
    }
  }

  // --------------------------------------------------------------------------
  // --- Hover
  // --------------------------------------------------------------------------

  _findHover(elt) {
    const buffer = this.props.buffer ;
    var best = undefined ;
    elt.classList.forEach((name) => {
      const hover = buffer.findHover(name);
      if (hover && (!best || hover.length < best.length )) best = hover ;
    });
    return best;
  }

  _findDecoration(classes,buffer,decorator)
  {
    var best_hover = undefined ;
    var best_decor = undefined ;
    var best_decoration = undefined ;
    classes.forEach((name) => {

      const hover = buffer.findHover(name);
      var decoration = hover && hover.id && decorator(hover.id);

      if (hover && (!best_hover || hover.length < best_hover.length))
        best_hover = hover ;

      if (decoration && (!best_decor || hover.length < best_decor.length)) {
        best_decor = hover ;
        best_decoration = decoration ;
      }

    });
    return best_hover && { classNameId: best_hover.classNameId , decoration: best_decoration } ;
  }

  _markElementsWith(classNameId,className) {
    const root = this.rootElement ;
    const tohover = root && root.getElementsByClassName(classNameId);
    const n = tohover ? tohover.length : 0 ;
    for (var k = 0; k < n; k++) tohover[k].classList.add(className);
  }

  _unmarkElementsWith(className) {
    const root = this.rootElement ;
    const hovered = root && root.getElementsByClassName(className);
    const n = hovered ? hovered.length : 0 ;
    if (n==0) return ;
    const elts = new Array(n); ;
    for (var k = 0; k < n; k++) elts[k] = hovered[k];
    elts.forEach((elt) => elt.classList.remove(className));
  }

  handleHover(target) {
    // Throttled (see constructor)
    const older = this.hover ;
    const hover = this._findHover(target);
    if (older !== hover) {
      if (older) this._unmarkElementsWith( CSS_HOVERED );
      if (hover && hover.hover) this._markElementsWith( hover.classNameId, CSS_HOVERED );
      this.hover = hover ;
    }
  }

  handleUpdate() {
    const root = this.rootElement ;
    const marked = root && root.getElementsByClassName('dome-xMarked');
    const n = marked ? marked.length : 0 ;
    if (n==0) return;
    const hover = this.hover ;
    const hovered = hover && hover.hover && hover.classNameId ;
    const selection = this.props.selection ;
    const selected = selection && ('dome-xMark-' + selection) ;
    const buffer = this.props.buffer;
    const decorator = buffer.getDecorator();
    if ( !hovered && !selection && !decorator ) return;
    const actual = {} ;
    for (var k = 0; k < n; k++) {
      const elt = marked[k];
      const classes = elt.classList ;
      if (hovered && classes.contains(hovered)) classes.add( CSS_HOVERED );
      if (selected && classes.contains(selected)) classes.add( CSS_SELECTED );
      if (decorator) {
        const hover = this._findDecoration(classes,buffer,decorator,hovered,selected);
        if (hover) {
          const prev = this.decorations[ hover.classNameId ];
          const curr = hover.decoration ;
          if (prev !== curr && prev) classes.remove(prev);
          if (curr) { classes.add(curr); actual[ hover.classNameId ] = curr ; }
        }
      }
    }
    this.decorations = actual ;
  }

  onMouseMove(evt) {
    // Not throttled (can not leak Synthetic Events)
    this.handleHover( evt.target );
  }

  onMouseClick(evt,callback) {
    // No need for throttling
    const target = evt.target ;
    if ( target && callback ) {
      const hover = this._findHover(target);
      if ( hover && hover.id ) callback( hover.id );
    }
    this.props.buffer.setFocused(true);
  }

  onClick(evt) { this.onMouseClick(evt,this.props.onSelection); }
  onContextMenu(evt) { this.onMouseClick(evt,this.props.onContextMenu); }

  // --------------------------------------------------------------------------
  // --- Scrolling
  // --------------------------------------------------------------------------

  handleScrollTo(position) {
    try {
      const cm = this.codeMirror;
      cm && cm.scrollIntoView(position);
    } catch(_error) { } // Out of range
  }

  // --------------------------------------------------------------------------
  // --- Focus
  // --------------------------------------------------------------------------

  handleKey(cm,key,_evt) {
    switch(key) {
    case 'Esc':
      this.props.buffer.setFocused(false);
      break;
    default:
      this.props.buffer.setFocused(true);
      break;
    }
  }

  onFocus() { this.props.buffer.setFocused(true); }
  onBlur() { this.props.buffer.setFocused(false); }
  onScroll() {
    const cm = this.codeMirror;
    if (cm) {
      const rect = cm.getScrollInfo();
      const delta = rect.height-rect.top-rect.clientHeight;
      const buffer = this.props.buffer;
      buffer.setFocused(delta > 0);
    }
  }

  // --------------------------------------------------------------------------
  // --- Rendering
  // --------------------------------------------------------------------------

  shouldComponentUpdate(newProps) {
    const cm = this.codeMirror ;
    if (cm) {
      // Swap documents if necessary
      const { buffer:oldBuffer,
              selection:oldSelect,
              ...oldConfig } = this.props ;
      const { buffer:newBuffer,
              selection:newSelect,
              ...newConfig } = newProps ;
      if (oldBuffer !== newBuffer) {
        const newDoc = newBuffer.getDoc();
        const oldDoc = cm.swapDoc( newDoc );
        oldBuffer.unlinkDoc( oldDoc );
      }
      // Incremental update options
      var opt ;
      for ( opt in oldConfig ) if (!(opt in newConfig)) {
        const defValue = CodeMirror.defaults[opt];
        if (defValue)
          cm.setOption( opt , defValue );
      }
      for ( opt in newConfig ) {
        const oldValue = oldConfig[opt];
        const newValue = newConfig[opt];
        if (newValue !== oldValue) {
          cm.setOption( opt , newValue );
        }
      }
      // Update selection
      if ( oldSelect !== newSelect ) {
        if (oldSelect) this._unmarkElementsWith( CSS_SELECTED );
        if (newSelect) this._markElementsWith( 'dome-xMark-' + newSelect, CSS_SELECTED );
      }
    }
    // Keep mounted node unchanged
    return false;
  }

  render() {
    const { className, fontSize, style } = this.props ;
    const theStyle = Object.assign( {} , style );
    if (fontSize) theStyle.fontSize = fontSize ;
    return (
      <div className={'dome-xText ' + className}
           style={theStyle}
           ref={this.mountPoint}
           onClick={this.onClick}
           onContextMenu={this.onContextMenu}
           onBlur={this.onBlur}
           onFocus={this.onFocus}
           onScroll={this.onScroll}
           onMouseMove={this.onMouseMove}
           />);
  }

}

// --------------------------------------------------------------------------
