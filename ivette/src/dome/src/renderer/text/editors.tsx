// --------------------------------------------------------------------------
// --- Text Documents
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/text/editors
*/

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import { Vfill } from 'dome/layout/boxes';
import CodeMirror, { EditorConfiguration } from 'codemirror/lib/codemirror.js';
import { RichTextBuffer, CSSMarker, Decorator } from './buffers';

import './style.css';
import 'codemirror/lib/codemirror.css';

const CSS_HOVERED = 'dome-xText-hover';
const CSS_SELECTED = 'dome-xText-select';

/* --------------------------------------------------------------------------*/
/* --- View Properties                                                   --- */
/* --------------------------------------------------------------------------*/

export interface MarkerCallback {
  (id: string): void;
}

/**
   @property {Buffer} buffer - associated Buffer holding the text content
   @property {string} className - additional class name(s)
   @property {object} style - additional CSS style
   @property {number} fontSize - editor font-size
   @property {string} selection - currently selected markder identifier
   @property {function} onSelection - callback used when an identified marker is clicked
   @property {function} onContextMenu - selection callback on right-click
   @property {object} [...options] - additional CodeMirror
   [configuration](https://codemirror.net/doc/manual.html#config) properties
 */

export interface TextProps extends CodeMirror.EditorConfiguration {

  /** The buffer to view. */
  buffer: RichTextBuffer | undefined;

  /** The currently selected marker identifier. */
  selection?: string;

  /** Callback on identified marker selection. */
  onSelection?: MarkerCallback;

  /** Callback on identified marker right-click. */
  onContextMenu?: MarkerCallback;

  /** Font Size. */
  fontSize?: number;

  /** Additional className for the text container. */
  className?: string;

  /** Additional style. */
  style?: React.CSSProperties;

}

/* --------------------------------------------------------------------------*/
/* --- CodeMirror Configuration Utils                                     ---*/
/* --------------------------------------------------------------------------*/

function getConfig(props: TextProps): CodeMirror.EditorConfiguration {
  const {
    buffer,
    selection,
    onSelection,
    onContextMenu,
    fontSize,
    ...config
  } = props;
  return config;
}

type MouseEvt = React.MouseEvent<HTMLDivElement, MouseEvent>;
type CMoption = keyof EditorConfiguration;

function forEachOption(
  config: EditorConfiguration,
  fn: (opt: CMoption) => void,
) {
  (Object.keys(config) as (keyof EditorConfiguration)[]).forEach(fn);
}

// --------------------------------------------------------------------------
// --- Code Mirror Instance Wrapper
// --------------------------------------------------------------------------

class CodeMirrorWrapper extends React.Component<TextProps> {

  private currentParent?: Element | null;
  private currentHeight?: number;
  private currentWidth?: number;
  private rootElement: HTMLDivElement | null = null;
  private codeMirror?: CodeMirror.Editor;
  private refreshPolling?: NodeJS.Timeout;

  // Currently hovered 'dome-xHover-nnn'
  private marker?: CSSMarker;

  // Maps hovered 'dome-xMark-id' to their decorations
  private decorations = new Map<string, string>();

  constructor(props: TextProps) {
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
    this.handleHover = _.throttle(this.handleHover, 50);
    this.handleScrollTo = this.handleScrollTo.bind(this);
  }

  // --------------------------------------------------------------------------
  // --- Mounting
  // --------------------------------------------------------------------------

  mountPoint(elt: HTMLDivElement | null) {
    this.rootElement = elt;
    if (elt !== null) {
      // Mounting...
      const { buffer } = this.props;
      const config = getConfig(this.props);
      const cm = this.codeMirror = CodeMirror(elt, { value: '' });
      if (buffer) {
        buffer.link(cm);
        buffer.on('decorated', this.handleUpdate);
        buffer.on('scroll', this.handleScrollTo);
      }
      // Passing all options to constructor does not work (Cf. CodeMirror's BTS)
      forEachOption(config, (opt) => cm.setOption(opt, config[opt]));
      // Binding events to view
      cm.on('update', this.handleUpdate);
      cm.on('keyHandled', this.handleKey);
      Dome.on('dome.update', this.refresh);
      // Auto refresh
      this.refreshPolling = setInterval(this.autoRefresh, 250);
      this.handleUpdate();
    } else {
      // Unmounting...
      const polling = this.refreshPolling;
      if (polling) {
        clearInterval(polling);
        this.refreshPolling = undefined;
      }
      const cm = this.codeMirror;
      Dome.off('dome.update', this.refresh);
      const { buffer } = this.props;
      if (cm && buffer) {
        buffer.unlink(cm);
        buffer.off('decorated', this.handleUpdate);
        buffer.off('scroll', this.handleScrollTo);
      }
      this.codeMirror = undefined;
      this.marker = undefined;
      this.decorations.clear();
    }
  }

  // --------------------------------------------------------------------------
  // --- Auto Refresh
  // --------------------------------------------------------------------------

  refresh() {
    const elt = this.rootElement;
    const cm = this.codeMirror;
    if (cm && elt) {
      this.currentWidth = elt.offsetWidth;
      this.currentHeight = elt.offsetHeight;
      this.currentParent = elt.offsetParent;
      cm.refresh();
    }
  }

  // Polled every 250ms
  autoRefresh() {
    const elt = this.rootElement;
    const cm = this.codeMirror;
    if (cm && elt) {
      const eltW = elt.offsetWidth;
      const eltH = elt.offsetHeight;
      const eltP = elt.offsetParent;
      if (eltW !== this.currentWidth ||
        eltH !== this.currentHeight ||
        eltP !== this.currentParent) {
        this.currentWidth = eltW;
        this.currentHeight = eltH;
        this.currentParent = eltP;
        cm.refresh();
      }
    }
  }

  // --------------------------------------------------------------------------
  // --- Hover
  // --------------------------------------------------------------------------

  _findMarker(elt: Element): CSSMarker | undefined {
    const { buffer } = this.props;
    if (buffer) {
      var best: CSSMarker | undefined;
      elt.classList.forEach((name) => {
        const marker = buffer.findHover(name);
        if (marker && (!best || marker.length < best.length)) best = marker;
      });
      return best;
    }
    return undefined;
  }

  _findDecoration(
    classes: DOMTokenList,
    buffer: RichTextBuffer,
    decorator: Decorator,
  ) {
    var best_marker: CSSMarker | undefined;
    var best_decorated: CSSMarker | undefined;
    var best_decoration: string | undefined;
    classes.forEach((name) => {

      const marker = buffer.findHover(name);
      const id = marker && marker.id;
      const decoration = id && decorator(id);

      if (marker && (!best_marker || marker.length < best_marker.length)) {
        best_marker = marker;
      }

      if (marker && decoration && (!best_decorated || marker.length < best_decorated.length)) {
        best_decorated = marker;
        best_decoration = decoration;
      }

    });
    return best_marker ? {
      classNameId: best_marker.classNameId,
      decoration: best_decoration,
    } : undefined;
  }

  _markElementsWith(classNameId: string, className: string) {
    const root = this.rootElement;
    const toMark = root && root.getElementsByClassName(classNameId);
    if (toMark) {
      const n = toMark.length;
      if (n === 0) return;
      for (var k = 0; k < n; k++) toMark[k].classList.add(className);
    }
  }

  _unmarkElementsWith(className: string) {
    const root = this.rootElement;
    const toUnmark = root && root.getElementsByClassName(className);
    if (toUnmark) {
      const n = toUnmark.length;
      if (n === 0) return;
      const elts: Element[] = new Array(n);;
      for (var k = 0; k < n; k++) elts[k] = toUnmark[k];
      elts.forEach((elt) => elt.classList.remove(className));
    }
  }

  handleHover(target: Element) {
    // Throttled (see constructor)
    const old_marker = this.marker;
    const new_marker = this._findMarker(target);
    if (old_marker !== new_marker) {
      if (old_marker) this._unmarkElementsWith(CSS_HOVERED);
      if (new_marker && new_marker.hover)
        this._markElementsWith(new_marker.classNameId, CSS_HOVERED);
      this.marker = new_marker;
    }
  }

  handleUpdate() {
    const root = this.rootElement;
    const marked = root && root.getElementsByClassName('dome-xMarked');
    if (!marked) return;
    const n = marked.length;
    if (n === 0) return;
    const marker = this.marker;
    const hovered = (marker && marker.hover) ? marker.classNameId : undefined;
    const selection = this.props.selection;
    const selected = selection && ('dome-xMark-' + selection);
    const { buffer } = this.props;
    const decorator = buffer?.getDecorator();
    if (!hovered && !selection && !decorator) return;
    const newDecorations = new Map<string, string>();
    for (var k = 0; k < n; k++) {
      const elt = marked[k];
      const classes = elt.classList;
      if (hovered && classes.contains(hovered)) classes.add(CSS_HOVERED);
      if (selected && classes.contains(selected)) classes.add(CSS_SELECTED);
      if (buffer && decorator) {
        const deco = this._findDecoration(classes, buffer, decorator);
        if (deco) {
          const prev = this.decorations.get(deco.classNameId);
          const curr = deco.decoration;
          if (prev && prev !== curr) classes.remove(prev);
          if (curr) {
            classes.add(curr);
            newDecorations.set(deco.classNameId, curr);
          }
        }
      }
    }
    this.decorations = newDecorations;
  }

  onMouseMove(evt: MouseEvt) {
    // Not throttled (can not leak Synthetic Events)
    const tgt = evt.target;
    if (tgt instanceof Element) this.handleHover(tgt);
  }

  onMouseClick(evt: MouseEvt, callback: MarkerCallback | undefined) {
    // No need for throttling
    const target = evt.target;
    if (target instanceof Element && callback) {
      const marker = this._findMarker(target);
      if (marker && marker.id) callback(marker.id);
    }
    this.props.buffer?.setFocused(true);
  }

  onClick(evt: MouseEvt) {
    this.onMouseClick(evt, this.props.onSelection);
  }

  onContextMenu(evt: MouseEvt) {
    this.onMouseClick(evt, this.props.onContextMenu);
  }

  // --------------------------------------------------------------------------
  // --- Scrolling
  // --------------------------------------------------------------------------

  handleScrollTo(line: number) {
    try {
      const cm = this.codeMirror;
      cm && cm.scrollIntoView({ line, ch: 0 });
    } catch (_error) { } // Out of range
  }

  // --------------------------------------------------------------------------
  // --- Focus
  // --------------------------------------------------------------------------

  handleKey(_cm: CodeMirror.Editor, key: string, _evt: KeyboardEvent) {
    switch (key) {
      case 'Esc':
        this.props.buffer?.setFocused(false);
        break;
      default:
        this.props.buffer?.setFocused(true);
        break;
    }
  }

  onFocus() { this.props.buffer?.setFocused(true); }
  onBlur() { this.props.buffer?.setFocused(false); }
  onScroll() {
    const cm = this.codeMirror;
    const { buffer } = this.props;
    if (cm && buffer) {
      const rect = cm.getScrollInfo();
      const delta = rect.height - rect.top - rect.clientHeight;
      buffer.setFocused(delta > 0);
    }
  }

  // --------------------------------------------------------------------------
  // --- Rendering
  // --------------------------------------------------------------------------

  shouldComponentUpdate(newProps: TextProps) {
    const cm = this.codeMirror;
    if (cm) {
      // Swap documents if necessary
      const {
        buffer: oldBuffer,
        selection: oldSelect,
        fontSize: oldFont
      } = this.props;
      const {
        buffer: newBuffer,
        selection: newSelect,
        fontSize: newFont
      } = newProps;
      if (oldBuffer !== newBuffer) {
        if (oldBuffer) oldBuffer.unlink(cm);
        if (newBuffer) newBuffer.link(cm);
        else cm.setValue('');
      }
      const oldConfig = getConfig(this.props);
      const newConfig = getConfig(newProps);
      // Incremental update options
      forEachOption(oldConfig, (opt) => {
        if (!(opt in newConfig)) {
          const defValue = CodeMirror.defaults[opt];
          if (defValue)
            cm.setOption(opt, defValue);
        }
      });
      forEachOption(newConfig, (opt) => {
        const oldValue = oldConfig[opt];
        const newValue = newConfig[opt];
        if (newValue !== oldValue) {
          cm.setOption(opt, newValue);
        }
      });
      // Update selection
      if (oldSelect !== newSelect) {
        const selected = 'dome-xMark-' + newSelect;
        if (oldSelect) this._unmarkElementsWith(CSS_SELECTED);
        if (newSelect) this._markElementsWith(selected, CSS_SELECTED);
      }
      // Refresh on new font
      if (oldFont !== newFont) setImmediate(this.refresh);
    }
    // Keep mounted node unchanged
    return false;
  }

  render() {
    return (
      <div className={'dome-xText'}
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
// --- Text View
// --------------------------------------------------------------------------

/**
   Text Editor.

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
export function Text(props: TextProps) {
  let { className, style, fontSize, ...cmprops } = props;
  if (fontSize !== undefined && fontSize < 4) fontSize = 4;
  if (fontSize !== undefined && fontSize > 48) fontSize = 48;
  const theStyle = Object.assign({}, style);
  theStyle.fontSize = fontSize;
  return (
    <Vfill className={className} style={theStyle}>
      <CodeMirrorWrapper fontSize={fontSize} {...cmprops} />
    </Vfill>
  );
}

// --------------------------------------------------------------------------
