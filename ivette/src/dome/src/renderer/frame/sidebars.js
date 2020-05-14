// --------------------------------------------------------------------------
// --- SideBars
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/frame/sidebars
*/

import React from 'react' ;
import * as Dome from 'dome' ;
import { Badge } from 'dome/controls/icons' ;
import { Label } from 'dome/controls/labels' ;

import './style.css' ;

const SideBarContext = React.createContext();

// --------------------------------------------------------------------------
// --- SideBar Container
// --------------------------------------------------------------------------

/**
   @summary Container for sidebar items.
   @property {Elements} [children] - Side bar items
   @property {string} [settings] - Side bar items settings
   @property {string} [selection] - Current item selection
   @property {function} [onSelection] - Selection callback
   @property {function} [onContextMenu] - Context Menu callback
   @description

   When a base settings is set on the sidebar, all contained
   sections and items are attributed derived settings based on their identifiers.

   The global selection state and callback are also propagated to the side bar items.
 */
export const SideBar = ({ children , ...props }) => (
  <div className="dome-xSideBar dome-color-frame">
    <SideBarContext.Provider value={props}>
      {children}
    </SideBarContext.Provider>
  </div>
);

const makeSettings = ( globalSettings, { settings, label, id } ) => {
  if (settings) return settings ;
  if (globalSettings) {
    let localId = id || label ;
    if (localId)
      return globalSettings + '.' + localId ;
  }
  return undefined ;
};

// --------------------------------------------------------------------------
// --- Badges Specifications
// --------------------------------------------------------------------------

const makeBadge = ((element) => {
  switch(typeof(element)) {
  case 'number':
  case 'string':
    return <Badge value={element}/>;
  default:
    return element ;
  }
});

// --------------------------------------------------------------------------
// --- SideBar Section Hide/Show Button
// --------------------------------------------------------------------------

const HideShow = (props) => (
  <label className='dome-xSideBarSection-hideshow dome-text-label'
         onClick={props.onClick} >
    {props.visible ? 'Hide' : 'Show'}
  </label>
);

// --------------------------------------------------------------------------
// --- SideBar Section
// --------------------------------------------------------------------------

const disableAll = (children) =>
      React.Children.map( children , (elt) => React.cloneElement( elt , { disabled: true } ) );

/**
   @summary Sidebar Section.
   @property {string} [id] - Section identifier (used for derived settings)
   @property {string} label - **Section label**
   @property {string} [title] - Section short description (label tooltip)
   @property {boolean} [enabled] - Enabled section (by default)
   @property {boolean} [disabled] - Disabled section (not by default)
   @property {boolean} [unfold] - Fold/unfold local state (default to local state)
   @property {string} [settings] - Fold/unfold window settings (local state)
   @property {boolean} [defaultUnfold] - Fold/unfold default state (default is `true`)
   @property {Badge} [summary] - Badge summary (when content is hidden)
   @property {Item[]} children - Content items
   @description

   Unless specified, sections can be hidden on click. When items in the section have badge(s)
   it is highly recommended to provide a badge summary to be displayed
   when the content is hidden.

   Sections with no items are not displayed.
*/
export function Section(props) {

  const context = React.useContext( SideBarContext );
  const [ state=true, setState ] = Dome.useState(
    makeSettings(context,props),
    props.defaultUnfold
  );
  const { enabled=true, disabled=false, unfold, children } = props ;

  if (React.Children.count(children) == 0) return null;

  const dimmed = context.disabled || disabled || !enabled ;
  const foldable = unfold === undefined ;
  const visible = foldable ? state : unfold ;
  const onClick = foldable ? (() => setState(!state)) : undefined ;
  const maxHeight = visible ? 2000 : 0 ;
  const subContext = Object.assign( {}, context, { disabled: dimmed } );

  return (
    <div className='dome-xSideBarSection'>
      <div className='dome-xSideBarSection-title' title={props.label}>
        <Label className={ dimmed ? 'dome-disabled' : '' } label={props.label} />
        {!visible && React.Children.map(props.summary,makeBadge)}
        {foldable && <HideShow visible={visible} onClick={onClick}/>}
      </div>
      <div className='dome-xSideBarSection-content' style={{ maxHeight }}>
        <SideBarContext.Provider value={subContext}>
          {children}
        </SideBarContext.Provider>
      </div>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- SideBar Items
// --------------------------------------------------------------------------

/**
   @summary Sidebar Section Items.
   @property {string} [id] - Item identifier
   @property {string} [label] - **Item label**
   @property {string} [icon] - Item icon
   @property {string} [title] - Item tooltip
   @property {boolean} [enabled] - Enabled item (default is `true`)
   @property {boolean} [disabled] - Disabled item (default is `false`)
   @property {boolean} [selected] - Item selection state (default is `SideBar` selection)
   @property {function} [onSelection] - Selection callback
   @property {function} [onContextMenu] - Context Menu callback
   @property {Badge} [badge] - Badge element(s)
   @property {React.Children} [children] - Item additional content
   @description

   The item will be highlighted if selected _via_ the `selection` property of the
   englobing sidebar. The `onSelection` and `onContextMenu` callbacks are invoked with the item identifier.
   Context menu callback also triggers the selection callback (first).
   In case callbacks are defined from the englobing sidebar, both are invoked.

   Badges can be single or multiple [[Badge]] values.
   They are displayed stacked on the right edge of the item.

**/
export function Item(props)
{
  const { selection,
          disabled: disabledSection,
          onSelection: ctxtOnSelect,
          onContextMenu: ctxtOnPopup
        } = React.useContext(SideBarContext);
  const { id, selected,
          disabled=false, enabled=true,
          onSelection:itemOnSelect,
          onContextMenu:itemOnPopup
        } = props ;
  const isDisabled = disabled || !enabled || disabled ;
  const isSelected = selected !== undefined ? selected : (selection && id && (selection === id)) ;
  const onClick = isDisabled ? undefined : () => {
    itemOnSelect && itemOnSelect(id);
    ctxtOnSelect && ctxtOnSelect(id);
  };
  const onContextMenu = isDisabled ? undefined : () => {
    onClick();
    itemOnPopup && itemOnPopup(id);
    ctxtOnPopup && ctxtOnPopup(id);
  };
  const classes = 'dome-xSideBarItem'
        + ( isSelected ? ' dome-active' : ' dome-inactive' )
        + ( isDisabled ? ' dome-disabled' : '' );
  return (
    <div className={classes} title={props.title}
         onContextMenu={onContextMenu}
         onClick={onClick}>
      <Label icon={props.icon} label={props.label} />
      {props.children}
      {React.Children.map(props.badge,makeBadge)}
    </div>
  );
}

// --------------------------------------------------------------------------

import { register } from 'dome/misc/register' ;

register( SideBar, 'DOME_SIDEBAR' );
register( Section, 'DOME_SIDEBAR_ITEM' );
register( Item,    'DOME_SIDEBAR_ITEM' );

// --------------------------------------------------------------------------
