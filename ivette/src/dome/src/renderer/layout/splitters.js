// --------------------------------------------------------------------------
// --- Splitters
// --------------------------------------------------------------------------

/** @module dome/layout/splitters */

import React from 'react' ;
import Props from 'prop-types' ;
import Dome from 'dome' ;
import { Layout } from 'dome/misc/events' ;
import './splitters.css' ;
import _ from 'lodash' ;

// --------------------------------------------------------------------------
// --- Splitter Layout
// --------------------------------------------------------------------------

const SUBVIEW = { overflow: 'hidden' };

const LAYOUT = {
  // Container Class
  hcursor: 'dome-xSplitter-h-cursor',
  vcursor: 'dome-xSplitter-v-cursor',
  nocursor: 'dome-xSplitter-no-cursor',
  // Grab Class
  hgrab: 'dome-xSplitter-grab dome-xSplitter-h dome-color-dragzone',
  vgrab: 'dome-xSplitter-grab dome-xSplitter-v dome-color-dragzone',
  hdrag: 'dome-xSplitter-grab dome-xSplitter-h dome-color-dragging',
  vdrag: 'dome-xSplitter-grab dome-xSplitter-v dome-color-dragging',
  // Non-Positionned Splitter Styles
  hsplitter: { width:1, height: '100%' },
  vsplitter: { height:1, width: '100%' },
  // Hidden style
  hide: { display: 'none' },
  // Non-Positionned Pane Styles
  fixH: { flex: 'none', height: 'auto', width: '100%' },
  extH: { flex: 'auto', minHeight: 30, width: '100%' },
  fixW: { flex: 'none', width: 'auto', height: '100%' },
  extW: { flex: 'auto', minWidth: 10, height: '100%' },
  // Non-Positionned Contailer Styles
  horizontal: {
    display:'flex', flexFlow: 'row nowrap'
  },
  vertical: {
    display:'flex', flexFlow: 'column nowrap'
  },
  // Positionned Container Style
  container: {
    display:'block'
  }
};

const subview = ( primary,secondary ) =>
      Object.assign( {} , SUBVIEW , { primary,secondary } );

// Tabulated flex-box styles
const FLEX = {
  'HORIZONTAL': subview( LAYOUT.extW, LAYOUT.extW ),
  'LEFT':       subview( LAYOUT.fixW, LAYOUT.extW ),
  'RIGHT':      subview( LAYOUT.extW, LAYOUT.fixW ),
  'VERTICAL':   subview( LAYOUT.extH, LAYOUT.extH ),
  'TOP':        subview( LAYOUT.fixH, LAYOUT.extH ),
  'BOTTOM':     subview( LAYOUT.extH, LAYOUT.fixH )
};

// Tabulated hidden styles
const HIDDEN = {
  'HORIZONTAL': subview( LAYOUT.hide, LAYOUT.extW ),
  'LEFT':       subview( LAYOUT.hide, LAYOUT.extW ),
  'RIGHT':      subview( LAYOUT.extW, LAYOUT.hide ),
  'VERTICAL':   subview( LAYOUT.hide, LAYOUT.extH ),
  'TOP':        subview( LAYOUT.hide, LAYOUT.extH ),
  'BOTTOM':     subview( LAYOUT.extH, LAYOUT.hide )
};

// Horizontal / Vertical mode
const LR = {
  'HORIZONTAL': true,
  'LEFT':       true,
  'RIGHT':      true,
  'VERTICAL':   false,
  'TOP':        false,
  'BOTTOM':     false
};

// --------------------------------------------------------------------------
// --- Splitter Component
// --------------------------------------------------------------------------

/**
   @class
   @summary Draggable split pane.
   @property {Direction} [dir]  - Layout and dimensionning strategy
   @property {string} [settings] - User-settings key for persistent splitter position
   @property {number} [margin]  - Minimal margin from container edges
   @property {boolean} [unfold] - whether to display or not the slider component (by default)
   @description
   Layout two panels horizontally or vertically with a draggable splitter.
   Clicking the splitter bar with any modifier key restore its natural position.

   The visibility of the slider component (the fixed size one, or the primary one) can
   be defined by the `unfold` property.

   ##### Direction

   | Tag | Description
   |:-------------------:|-------------------------------------------------
   | `'HORIZONTAL'`      | Horizontal layout (default)
   | `'LEFT'`, `'RIGHT'` | Horizontal layout with _fixed_ left or right component
   | `'VERTICAL'`        | Vertical layout
   | `'TOP'`, `'BOTTOM'` | Vertical layout with _fixed_ top or bottom component

   When resizing the entire component, free available space is distributed among both children
   except when one is _fixed_ by the `dir` property.
   Typically, if your component has a left side-bar, you would provide a `LEFT` direction
   to the splitter.


   ##### Children

   The component is designed for two children. If no-children is given, the
   component returns `undefined`. If only one children is provided, it is
   rendered as is-it, without any additional decoration. Extra chidren after the
   2nd are simply not rendered.


   ##### Borders & Margin

   Primary and secondary components are laidout within positionned div elements with hidden overflows.
   If your components have borders, you should adjust their CSS box-sizing property to `'border-box'`.
   Margin with `'100%'` height or width should be avoided and replaced by padding, otherwize
   the left and bottom sides of the views are likely to be cropped.

*/

export class Splitter extends React.Component {

  // --------------------------------------------------------------------------
  // --- Life Cycle
  // --------------------------------------------------------------------------

  constructor(props) {
    super(props);
    this.handleReset = this.handleReset.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.handleDragInit = this.handleDragInit.bind(this);
    this.handleDragMove = this.handleDragMove.bind(this);
    this.handleDragStop = this.handleDragStop.bind(this);
    this.doDragMove = _.throttle( this.doDragMove , 100 );
    this.lr = LR[ this.props.dir ];
    this.margin = Math.max( 32 , this.props.margin || 0 );
    this.state = {
      dragging: false,   // Splitter is currently dragging
      absolute: false,   // Splitter is positionned with offset
      anchor: 0,         // Invariant: anchor == mouse position - offset
      offset: 0          // Position of splitter edge from container edge
    };
  }

  // --------------------------------------------------------------------------
  // --- Mounting
  // --------------------------------------------------------------------------

  componentDidMount() {
    if (this.refs.container && this.refs.splitter) {
      const container = this.refs.container.getBoundingClientRect() ;
      const dimension = this.lr ? container.width : container.height ;
      this.range = dimension - this.margin ;
      const settings = this.props.settings ;
      if (settings) {
        const offset = Dome.getWindowSetting(settings,-1);
        if (this.margin <= offset && offset <= this.range)
          this.setState({ absolute: true, offset });
      }
    }
    Dome.on( 'dome.defaults', this.handleReset );
  }

  componentWillUnmount() {
    Dome.off( 'dome.defaults', this.handleReset );
  }

  componentDidUpdate() {
    this.lr = LR[ this.props.dir ];
    this.margin = Math.max( 32 , this.props.margin || 0 );
  }

  // --------------------------------------------------------------------------
  // --- Reset Offset
  // --------------------------------------------------------------------------

  handleReset() {
    this.setState({ absolute: false, dragging: false, anchor: 0, offset: 0 });
    Dome.setWindowSetting(this.props.settings, -1);
  }

  handleClick(event) {
    if (event.altKey || event.ctrlKey || event.cmdKey || event.shiftKey)
      this.handleReset();
  }

  // --------------------------------------------------------------------------
  // --- Resizing Handler
  // --------------------------------------------------------------------------

  handleResize() {
    // Defensive
    if (this.refs.container && this.refs.splitter && this.state.absolute) {
      let container = this.refs.container.getBoundingClientRect() ;
      let dimension = this.lr ? container.width : container.height ;
      if (dimension == 0) return;
      let newrange = dimension - this.margin ;
      let newoffset ;
      switch(this.props.dir) {
      case 'LEFT':
      case 'TOP':
        newoffset = this.state.offset ;
        break;
      case 'RIGHT':
      case 'BOTTOM':
        newoffset = this.state.offset + newrange - this.range ;
        break;
      default:
        newoffset = this.state.offset + (newrange - this.range) / 2 ;
        break;
      }
      this.range = newrange ;
      if ( this.margin <= this.range) {
        if (newoffset > this.range) newoffset = this.range ;
        if (newoffset < this.margin) newoffset = this.margin ;
      } else {
        newoffset = dimension / 2 ;
      }
      this.setState( { offset: newoffset } );
    }
  }

  // --------------------------------------------------------------------------
  // --- Init Drag
  // --------------------------------------------------------------------------

  handleDragInit(evt) {
    evt.preventDefault();
    // Invariant: offset == position - anchor
    let position = this.lr ? evt.clientX : evt.clientY ;
    // Defensive
    if (this.refs.splitter && this.refs.container) {
      let splitter = this.refs.splitter.getBoundingClientRect() ;
      let container = this.refs.container.getBoundingClientRect() ;
      let dimension = this.lr ? container.width : container.height ;
      let offset = this.lr
          ? splitter.left - container.left
          : splitter.top - container.top ;
      this.range = dimension - this.margin ;
      if (this.margin <= offset && offset <= this.range) {
        let anchor = position - offset ;
        this.setState( { dragging: true, absolute: true,
                         anchor: anchor, offset: offset } );
      }
    }
  }

  // --------------------------------------------------------------------------
  // --- Move Drag
  // --------------------------------------------------------------------------

  // Throttled 100ms
  doDragMove(client) {
    // Invariant: offset == position - anchor
    let offset = client - this.state.anchor ;
    if (this.margin <= offset && offset <= this.range)
      this.setState( { offset: offset, absolute: true } );
  }

  // Not throttled (non-persistent event)
  handleDragMove(evt) {
    this.doDragMove(this.lr ? evt.clientX : evt.clientY);
  }

  // --------------------------------------------------------------------------
  // --- Stop Drag
  // --------------------------------------------------------------------------

  handleDragStop(evt) {
    Dome.setWindowSetting( this.props.settings, this.state.offset );
    this.setState({ dragging: false });
  }

  // --------------------------------------------------------------------------
  // --- Rendering
  // --------------------------------------------------------------------------

  render() {
    const children = this.props.children ;
    switch(children.length) {
    case 0:
      return undefined;
    case 1:
      return children[0];
    default:
      let dir = this.props.dir;
      let dragging = this.state.dragging;
      let offset = this.state.offset;
      let cursor = dragging
          ? (this.lr ? LAYOUT.hcursor : LAYOUT.vcursor)
          : LAYOUT.nocursor ;
      let grab = this.state.dragging
          ? (this.lr ? LAYOUT.hdrag : LAYOUT.vdrag )
          : (this.lr ? LAYOUT.hgrab : LAYOUT.vgrab ) ;
      let container, splitter, primary, secondary ;
      let { unfold=true } = this.props ;
      let absolute = this.state.absolute ;
      if (!unfold)
      {
        container = LAYOUT.container ;
        splitter = LAYOUT.hide ;
        let hidden = HIDDEN[dir] ;
        primary = hidden.primary ;
        secondary = hidden.secondary ;
      }
      else if (!absolute)
      {
        container  = this.lr ? LAYOUT.horizontal : LAYOUT.vertical ;
        splitter   = this.lr ? LAYOUT.hsplitter : LAYOUT.vsplitter ;
        let flex = FLEX[dir];
        primary    = flex.primary ;
        secondary  = flex.secondary ;
      }
      else
      {
        container  = LAYOUT.container ;
        if (this.lr) {
          primary   = { position: 'absolute', left: 0, width: offset, height: '100%' };
          splitter  = { position: 'absolute', left: offset, width: 1, height: '100%' };
          secondary = { position: 'absolute', left: offset+1, right: 0, height: '100%' };
        } else {
          primary   = { position: 'absolute', top: 0, height: offset, width: '100%' };
          splitter  = { position: 'absolute', top: offset, height: 1, width: '100%' };
          secondary = { position: 'absolute', top: offset+1, bottom: 0, width: '100%' };
        }
        Object.assign( primary , SUBVIEW );
        Object.assign( secondary , SUBVIEW );
      }
      return (
        <div ref="container"
             onMouseUp={dragging ? this.handleDragStop : undefined}
             onMouseMove={dragging ? this.handleDragMove : undefined}
             className={'dome-xSplitter-container ' + cursor}
             style={container}>
          <div ref="primary" style={primary} className='dome-xSplitPane dome-container'>
            {children[0]}
          </div>
          <div ref="splitter" style={splitter} className='dome-xSplitLine'>
            <div className={grab}
                 onMouseDown={this.handleDragInit}
                 onClick={absolute ? this.handleClick : undefined} />
          </div>
          <div ref="secondary" style={secondary} className='dome-xSplitPane dome-container'>
            {children[1]}
          </div>
          <Layout onResize={this.handleResize} />
        </div>
      );
    }
  }

}

// --------------------------------------------------------------------------
// --- Props & Defaults
// --------------------------------------------------------------------------

Splitter.propTypes = {
  dir: Props.oneOf(['HORIZONTAL','VERTICAL','LEFT','RIGHT','TOP','BOTTOM']),
  settings: Props.string,
  margin: Props.number
};

Splitter.defaultProps = {
  dir: 'HORIZONTAL',
  margin: 32
};

// --------------------------------------------------------------------------

export default { Splitter };

// --------------------------------------------------------------------------
