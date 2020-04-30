// --------------------------------------------------------------------------
// --- Box Layout
// --------------------------------------------------------------------------

/** @module dome/layout/boxes
    @description

This modules offers several `<div>` containers with various
predefined layout.

Boxes are the very elementary way to layout components horizontally
or vertically. The different kinds of proposed boxes differ in how they
extends in both directions: normal boxes extends
along their layout direction, _pack_ boxes don't extends and _fill_ boxes
extends along both directions.

Grids layout their component from left-to-right inside predefined _columns_,
then vertically by wrapping cells in rows.

The various containers are summarized on the table below:

| **Box** | Layout | Extends |
|:-------------:|:-----------:|:----------:|:----------:|
| [Hbox](module-dome_layout_boxes.Hpack.html) | horiz. | horiz. |
| [Vbox](module-dome_layout_boxes.Vpack.html) | vert. | vert. |
| [Hpack](module-dome_layout_boxes.Hpack.html) | horiz. | none |
| [Vpack](module-dome_layout_boxes.Vpack.html) | vert. | none |
| [Hfill](module-dome_layout_boxes.Hpack.html) | horiz. | both |
| [Vfill](module-dome_layout_boxes.Vpack.html) | vert. | both |
| [Grid](module-dome_layout_boxes.Hpack.html) | columns | both |
| [Scroll](module-dome_layout_boxes.Scroll.html) | n/a | both |

Inside a box, you may add `<Space/>` and `<Filler/>` to separate items.
Inside a grid, you may also use `<Space/>` or an empty `<div/>` for empty cells.

<strong>Warning:</strong> large elements will be clipped if they overflow.
If you want to add scrolling capabilities to some item that does not manage overflow
natively, place it inside a `<Scroll/>` sub-container.

*/

import React from 'react';
import * as Dome from 'dome';
import { Title } from 'dome/controls/labels' ;
import './style.css' ;

// --------------------------------------------------------------------------
// --- Generic Box
// --------------------------------------------------------------------------

const makeBox = ( boxClasses, props, morestyle ) => {
  const { children, className, style, ...others } = props ;
  const allClasses = className ? boxClasses + ' ' + className : boxClasses ;
  const allStyles = morestyle ? (style ? Object.assign( {}, style, morestyle ) : morestyle) : style ;
  return (
    <div className={allClasses} style={allStyles} {...others} >
      {children}
    </div>
  );
};

// --------------------------------------------------------------------------
// --- Predefined Defaults
// --------------------------------------------------------------------------

/**
   @summary Horizontal box (extends horizontally, no overflow).
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   <strong>Warning:</strong> large elements will be clipped if they overflow.
*/
export const Hbox = (props) => makeBox( 'dome-xBoxes-hbox dome-xBoxes-box' , props );

/**
   @summary Vertical box (extends vertically, no overflow).
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   <strong>Warning:</strong> large elements will be clipped if they overflow.
*/
export const Vbox = (props) => makeBox( 'dome-xBoxes-vbox dome-xBoxes-box' , props );

/**
   @summary Compact Horizontal box (fixed dimensions, no overflow).
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   <strong>Warning:</strong> large elements would be clipped if they overflow.
*/
export const Hpack = (props) => makeBox( 'dome-xBoxes-hbox dome-xBoxes-pack' , props );

/**
   @summary Compact Vertical box (fixed dimensions, no overflow).
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   <strong>Warning:</strong> large elements will be clipped if they overflow.
*/
export const Vpack = (props) => makeBox( 'dome-xBoxes-vbox dome-xBoxes-pack' , props );

/**
   @summary Horizontally filled box (fixed height, maximal width, no overflow).
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   <strong>Warning:</strong> large elements will be clipped if they overflow.
*/
export const Hfill = (props) => makeBox( 'dome-xBoxes-hbox dome-xBoxes-fill' , props );

/**
   @summary Vertically filled box (fixed width, maximal height, no overflow).
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   <strong>Warning:</strong> large elements will be clipped if they overflow.
*/
export const Vfill = (props) => makeBox( 'dome-xBoxes-vbox dome-xBoxes-fill' , props );

// --------------------------------------------------------------------------
// --- Scrolling & Spacing
// --------------------------------------------------------------------------

/**
   @summary Scrolling container.
   @property {object} [...props] - Extra properties passed to the `<div>` container
*/
export const Scroll = (props) => makeBox( 'dome-xBoxes-scroll dome-container' , props );

/**
   @summary Rigid space between items in a box.
   @property {object} [...props] - Extra properties passed to the `<div>` separator
*/
export const Space = (props) => makeBox( 'dome-xBoxes-space' , props );

/**
   @summary Extensible space between items in a box.
   @property {object} [...props] - Extra properties passed to the `<div>` separator
*/
export const Filler = (props) => makeBox( 'dome-xBoxes-filler' , props );

// --------------------------------------------------------------------------
// --- Grids
// --------------------------------------------------------------------------

/**
   @summary Grid box container.
   @property {string} [columns] - Grid column specifications
   @property {object} [...props] - Extra properties passed to the `<div>` container
   @description
   Layout its children in a multi-column grid. Each column is specified by its
   width, following the CSS Grid Layout `grid-template-columns` property.

   The rows are populated with children from left-to-right, using one column at a time.
   Items layout can be modified by adding CSS Grid Layout item properties.

   Example: `<Grid columns="25% auto auto"> ... </Grid>`
*/
export const Grid = ({columns='auto',...props}) =>
  makeBox( 'dome-xBoxes-grid', props , { gridTemplateColumns: columns });

// --------------------------------------------------------------------------
// --- Folders
// --------------------------------------------------------------------------

/**
   @summary Foldable Vpack box.
   @property {string} label - box label
   @property {string} [title] - box label tooltip
   @property {string} [settings] - window setting to store the fold/unfold state
   @property {boolean} [defaultUnfold] - initial state (default is `false`)
   @property {React.Children} [children] - content of the vertical box
   @description
   A vertical `Vpack` box with a clickable head label to fold/unfold its content.
*/
export const Folder =
  ({ settings, defaultUnfold=false, indent=18, label, title, children }) =>
{
  const [ unfold , setUnfold ] = Dome.useState( settings, defaultUnfold );
  const icon = unfold ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT' ;
  const onClick = () => setUnfold( !unfold );
  return (
    <Vpack>
      <Hpack onClick={onClick}><Title icon={icon} label={label} title={title} /></Hpack>
      <Vpack style={{ marginLeft:indent }}>
        { unfold && children }
      </Vpack>
    </Vpack>
  );
};

// --------------------------------------------------------------------------
