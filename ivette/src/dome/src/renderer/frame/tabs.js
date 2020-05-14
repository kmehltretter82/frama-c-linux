// --------------------------------------------------------------------------
// --- Tabs
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/frame/tabs
*/

import React from 'react' ;
import { Icon } from 'dome/controls/icons' ;

import './style.css' ;

/**
   @class
   @summary Pure Container for tab buttons.
   @description
   Shall contains only [[Tab]] instances.
*/
// --------------------------------------------------------------------------
// --- Tabs Bar
// --------------------------------------------------------------------------

export function TabsBar(props) {
  return (
    <div className='dome-xTabsBar dome-color-frame'>
      {props.children}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Single Tab
// --------------------------------------------------------------------------

const VISIBLE = { display: 'block' };
const HIDDEN  = { display: 'none' };

/**
   @class
   @summary Pure Component for rendering a tab button.
   @property {string} [id] - tab's identifier
   @property {component} [label] - tab's label
   @property {string} [title] - tab's tooltip
   @property {string} [closing] - closing button's tooltip (defaults to `"Close Tab"`)
   @property {string} [selection] - Currently selected tab identifier
   @property {function} [onSelection] - selection callcack, feed with value
   @property {function} [onClose] - selection callcack, feed with value
   @property {boolean} [default] - if `true`, selected tab by default
   @property {boolean} [content] - render content instead of tab
   @description
   A single tab selector. Shall only be used as a children
   of [[TabsBar]].

   When `content` is positionned, the component renders
   its content children instead of the tab button. In such a case, content
   is displayed only when selected.

   __Remark__: on Mac OSX, the close button appears on the left-side of the tab.
*/

export function Tab(props) {
  const selected = props.id === props.selection ;
  if (props.content) {
    //--- Content Rendering
    const style = selected ? VISIBLE : HIDDEN ;
    return (
      <div className='dome-xTab-content dome-container' style={style}>
        {props.children}
      </div>
    );
  } else {
    //--- Tab Rendering
    const onClick = props.onSelection && (() => props.onSelection(props.id));
    const onClose = props.onClose && (() => props.onClose(props.id));
    var closing = onClose ? (
      <Icon className="dome-xTab-closing"
            title={props.closing || "Close Tab"}
            name="CROSS" onClick={onClose} />
    ) : undefined ;
    const classes = 'dome-xTab' + ( selected ? ' dome-active' : ' dome-inactive' ) ;
    return (
      <label
        className={classes} title={props.title} onClick={onClick}>
        {props.label}
        {closing}
      </label>
    );
  }
}

// --------------------------------------------------------------------------
// --- TabsPane
// --------------------------------------------------------------------------

/**
   @class
   @summary Pure Container for tab contents.
   @property {string} selection - tab identifier to render
   @property {Tab[]} children - tabs (content) to render
   @description
   Shall contains [[Tab]] instances.
   Only the selected tab identifier will be displayed, although all tab
   contents remains properly mounted. If no tab is selected,
   no content is displayed.
*/

export function TabsPane({ selection, children }) {
  const showTab = (elt) => React.cloneElement(elt, { content: true, selection });
  return (
    <React.Fragment>
      {React.Children.map(children , showTab)}
    </React.Fragment>
  );
}

// --------------------------------------------------------------------------
// --- Dome Class (private)
// --------------------------------------------------------------------------

import { register } from 'dome/misc/register' ;

register(TabsBar, 'DOME_TABSBAR');
register(Tab,     'DOME_TABSBAR_ITEM');

// --------------------------------------------------------------------------
