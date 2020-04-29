// --------------------------------------------------------------------------
// --- ToolBars
// --------------------------------------------------------------------------

/** @module dome/layout/toolbars */

import React from 'react' ;
import './toolbars.css' ;

// --------------------------------------------------------------------------
// --- ToolBar Container
// --------------------------------------------------------------------------

/**
   @class
   @summary Container for toolbar items.
   @description
   See also [Frame](module-dome_layout_frames.Frame.html) containers.
 */
export class ToolBar extends React.Component {

  constructor(props) {
    super(props);
  }

  render() {
    const children = this.props.children ;
    return React.Children.count(children) > 0 && (
      <div className='dome-xToolBar dome-color-frame'>
        <div className='dome-xToolBar-inset'/>
        {children}
        <div className='dome-xToolBar-inset'/>
      </div>
    );
  }

}

// --------------------------------------------------------------------------
// --- ToolBar Spaces
// --------------------------------------------------------------------------

/**
   @summary Fixed (tiny) space.
*/
export const Inset = (() => <div className='dome-xToolBar-inset'/>);

/**
   @summary Fixed space.
*/
export const Space = (() => <div className='dome-xToolBar-space'/>);

/**
   @summary Extensible space (can be used to right-align controls).
*/
export const Filler = (() => <div className='dome-xToolBar-filler'/>);

/**
   @summary Vertical rule.
*/
export const Separator = () => (
  <div className='dome-xToolBar-separator'>
    <div className='dome-xToolBar-vrule'/>
  </div>
);

// --------------------------------------------------------------------------
// --- ToolBar Button
// --------------------------------------------------------------------------

import { SVG } from 'dome/controls/icons' ;

const SELECT = 'dome-xToolBar-Control dome-selected' ;
const BUTTON = 'dome-xToolBar-Control dome-color-frame' ;
const KIND = (kind) => kind ? ' dome-xToolBar-' + kind : '';

const isSelected = ( { selected , selection , value } ) => (
  selected !== undefined ? selected : ( value !== undefined && value === selection )
);

const isDisabled = ( { enabled=true, disabled=false } ) => (disabled || !enabled) ;
const onClick = ( { onClick , value } ) => onClick ? (() => onClick(value)) : undefined ;

/**
   @summary Toolbar Button.
   @property {string} [icon] - Button icon name (See [gallery](gallery-icons.html))
   @property {string} [label] - Button label
   @property {string} [title] - Button tooltip
   @property {string} [kind] - Styled button (see below)
   @property {boolean} [selected] - Selected button (default: `false`)
   @property {boolean} [disabled] - Disabled button (default: `false`)
   @property {boolean} [enabled] - Enabled button (default: `true`)
   @property {any} [value] - button's value
   @property {any} [selection] - Currently selected value
   @property {function} [onClick] - Button callback (receives the current value)
   @description

   By default, the propery `selected` is computed from properties `value`
   and `selection`, when provided.

   The callback is given the `value` property, if any.

   The different available kinds for styling a (non-selected) button are:
   - `'default'`: normal button;
   - `'cancel'`: normal button, in dark grey;
   - `'warning'`: warning button, in orange;
   - `'positive'`: positive button, in green;
   - `'negative'`: negative button, in red.

*/
export const Button = ( props ) => (
  <button
    disabled={isDisabled(props)}
    className={isSelected(props) ? SELECT : (BUTTON + KIND(props.kind))}
    onClick={onClick(props)}
    title={props.title}
    >
    {props.icon && <SVG id={props.icon} />}
    {props.label && <label>{props.label}</label>}
  </button>
);

// --------------------------------------------------------------------------
// --- ToolBar Button Group
// --------------------------------------------------------------------------

/**
   @summary Toolbar Button Group.
   @property {Button[]} children - Buttons in the group
   @property {any} [value] - Passed to children as `selection` property
   @property {any} [onChange] - Passed to children as `onClick` property
   @property {any} [...props] - Properties passed to all children
*/
export const ButtonGroup = (props) => {
  const { children, value, onChange, ...otherProps } = props;
  if (value !== undefined) otherProps.selection = value;
  if (onChange !== undefined) otherProps.onClick = onChange;
  return (
    <div className='dome-xToolBar-Group'>
      {React.Children.map(children, (elt) => React.cloneElement(elt, otherProps))}
    </div>
  );
};

// --------------------------------------------------------------------------
// --- ToolBar Menu
// --------------------------------------------------------------------------

/**
   @summary Toolbar Selector Menu.
   @property {any} [value] - selected option's value
   @property {function} [onChange] - selection callback (receives option value)
   @property {boolean} [disabled] - disable the selector (default: `false`)
   @property {boolean} [enabled] - enable the selector (default: `true`)
   @property {option[]} children - Array of menu options
   @description

   Behaves likes a standard `<select>` element, except that callback directly
   receives the select value, not the entire event.

   The list of options shall be given with standard `<option value={...} label={...}>`
   elements.

*/
export const Select = (props) => (
  <select className='dome-xToolBar-Control dome-color-frame'
          value={props.value}
          disabled={isDisabled(props)}
          onChange={(props.onChange && ((evt) => props.onChange(evt.target.value)))}
    >
    {props.children}
  </select>
);

// --------------------------------------------------------------------------
// --- Export & Registration
// --------------------------------------------------------------------------

import { register } from 'dome/misc/register' ;

register( ToolBar, 'DOME_TOOLBAR' );
register( Inset ,  'DOME_TOOLBAR_ITEM' );
register( Space ,  'DOME_TOOLBAR_ITEM' );
register( Separator ,  'DOME_TOOLBAR_ITEM' );
register( Filler , 'DOME_TOOLBAR_ITEM' );
register( Button , 'DOME_TOOLBAR_ITEM' );

export default { ToolBar , Space , Inset, Separator, Filler, Button, ButtonGroup, Select };

// --------------------------------------------------------------------------
