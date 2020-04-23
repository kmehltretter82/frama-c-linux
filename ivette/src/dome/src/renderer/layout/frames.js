// --------------------------------------------------------------------------
// --- Frames
// --------------------------------------------------------------------------

/** @module dome/layout/frames */

import React from 'react' ;
import Dome from 'dome' ;
import { dispatch } from 'dome/misc/register' ;
import { Vfill } from 'dome/layout/boxes' ;
import { SideBar } from 'dome/layout/sidebars' ;
import { ToolBar } from 'dome/layout/toolbars' ;
import { TabsBar , TabContent } from 'dome/layout/tabs' ;
import { Splitter } from 'dome/layout/splitters' ;

const callbacks = (f,g) => (f ? (g ? (id) => { f(id); g(id); } : f ) : g );

// --------------------------------------------------------------------------
// --- Frame Component
// --------------------------------------------------------------------------

/**
   @class
   @summary Main view with optional tabs, toolbar and sidebar.
   @property {string} [settings] - User-setting base name for
   persistent selection and customization
   @property {string} [selectedTab] - Currently selected tab
   @property {string} [selectedItem] - Currently selected sidebar item
   @property {string} [defaultTab] - Default selected tab (see also default tab's property)
   @property {string} [defaultItem] - Default selected item
   @property {function} [onTabClose] - tab closing callback
   @property {function} [onTabSelection] - tab selection callback
   @property {function} [onItemSelection] - sidebar item selection callback
   @property {boolean} [hideToolbar] - hide tool bar (default is `false`)
   @property {boolean} [hideTabsbar] - hide tabs bar (default is `false`)
   @description

   ##### Content
   The Frame layout and its decorations are specified according to
   the type of its children elements:
   - [Tab](module-dome_layout_tabs.Tab.html), if any, will be rendered into an optional
   [TabsBar](module-dome_layout_tabs.TabsBar.html) and the selected tab content
   will be rendered into the main content of the frame.
   - [Sidebar items](module-dome_layout_sidebars.html), if any, will be rendered
   inside a sidebar on the left of the frame.
   - [Toolbar items](module-dome_layout_toolbars.html), if any,
   will be rendered inside a toolbar on top of the frame.
   - The remaining elements will be rendered (inside a vertical box) into the
   main content the frame, provided there is no defined tab.


   ##### Callbacks
   Both general callbacks and tab ones are invoked
   when the user select or close a tab. The tab callbacks are invoked _before_ the
   frame ones.


   ##### Settings
   When provided, user selection will be saved in user's settings
   under the following keys (when relevant):
   - `'<settings>.dome.tab'` tab selection
   - `'<settings>.dome.item'` item selection
   - `'<settings>.dome.sidebar'` position of side-bar splitter
   - `'<settings>.dome.section'` visibility of side-bar sections
*/

export class Frame extends React.Component
{

  constructor(props)
  {
    super(props);
    const settings = props.settings ;
    const derived = ( selected , user , def ) =>
          (selected || ( settings && Dome.getWindowSetting( settings + user ) ) || def) ;
    var selectedTab = derived( props.selectedTab , '.dome.tab' , props.defaultTab );
    var selectedItem = derived( props.selectedItem , '.dome.item' , props.defaultItem );
    this.state = { selectedTab , selectedItem };
    this.handleSelectTab = this.handleSelectTab.bind(this);
    this.handleSelectItem = this.handleSelectItem.bind(this);
  }

  // --------------------------------------------------------------------------
  // --- Life Cycle
  // --------------------------------------------------------------------------

  componentWillMount() {
    const onTabSelection = this.props.onTabSelection ;
    if (onTabSelection) {
      const stateId = this.state.selectedTab ;
      const propsId = this.props.selectedTab ;
      if (stateId !== propsId) setImmediate(() => onTabSelection( stateId ));
    }
    const onItemSelection = this.props.onItemSelection ;
    if (onItemSelection) {
      const stateId = this.state.selectedItem ;
      const propsId = this.props.selectedItem ;
      if (stateId !== propsId) setImmediate(() => onItemSelection( stateId ));
    }
  }

  componentDidUpdate() {
    const tabid = this.props.selectedTab ;
    if (tabid && this.state.selectedTab !== tabid)
      this.setState( { selectedTab: tabid } );
    const itemid = this.props.selectedItem ;
    if (itemid && this.state.selectedItem !== itemid)
      this.setState( { selectedItem: itemid } );
  }

  // --------------------------------------------------------------------------
  // --- Update
  // --------------------------------------------------------------------------

  handleSelectTab(id) {
    this.setState( { selectedTab: id } );
    const settings = this.props.settings ;
    const onSelect = this.props.onTabSelection ;
    settings && Dome.setWindowSetting( settings + '.dome.tab' , id );
    onSelect && onSelect( id );
  }

  handleSelectItem(id) {
    this.setState( { selectedItem: id } );
    const settings = this.props.settings ;
    const onSelect = this.props.onItemSelection ;
    settings && Dome.setWindowSetting( settings + '.dome.item' , id );
    onSelect && onSelect( id );
  }

  // --------------------------------------------------------------------------
  // --- Rendering
  // --------------------------------------------------------------------------

  render() {

    const content = dispatch( this.props.children , {
      tabsItems: 'DOME_TABSBAR_ITEM',
      sideItems: 'DOME_SIDEBAR_ITEM',
      toolItems: 'DOME_TOOLBAR_ITEM',
      others: undefined
    });

    var selection = this.state.selectedTab ;
    if (selection === undefined)
      React.Children.forEach( content.tabsItems , (tab) => {
        if (!selection && tab && tab.props.default)
          selection = tab.props.ident ;
      });

    const makeTab = (tab) => {
      const onSelection = callbacks( tab.props.onSelection , this.handleSelectTab );
      const onClose  = callbacks( tab.props.onClose , this.props.onTabClose );
      const props = { selection , onSelection , onClose , content: false } ;
      return React.cloneElement( tab , props , null );
    };

    const makeContent = (tab) => {
      const props = {
        selection ,
        onSelection : undefined,
        onClose : undefined,
        content: true
      };
      return React.cloneElement( tab , props );
    };

    var tabs , main ;
    const settings = this.props.settings ;
    const tools = content.toolItems ;

    if (content.tabsItems) {
      tabs = React.Children.map( content.tabsItems , (tab) => tab && makeTab(tab) );
      main = React.Children.map( content.tabsItems , (tab) => tab && makeContent(tab) );
      if (content.others) console.warn('Unexpected main content for Frame with Tabs');
    } else {
      tabs = undefined ;
      main = content.others ;
    }

    if (content.sideItems) {
      const sidebarOffset = settings && (settings + '.dome.sidebar');
      const sidebarSections = settings && (settings + '.dome.section');
      main = (
        <Splitter dir='LEFT' settings={sidebarOffset} >
          { <SideBar
                settings={sidebarSections}
                selection={this.state.selectedItem}
                onSelection={this.handleSelectItem}
              >{content.sideItems}</SideBar> }
          { main }
        </Splitter>
      );
    }

    return (
      <Vfill>
        { !this.props.hideToolbar && tools && <ToolBar>{tools}</ToolBar> }
        { !this.props.hideTabsbar && tabs && <TabsBar>{tabs}</TabsBar> }
        { main }
      </Vfill>
    );
  }

}

// --------------------------------------------------------------------------

export default { Frame };

// --------------------------------------------------------------------------
