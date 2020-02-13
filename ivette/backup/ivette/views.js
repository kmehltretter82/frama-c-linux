// --------------------------------------------------------------------------
// ---  Lab View Component
// --------------------------------------------------------------------------

/** @module @ivette/views */

import _ from 'lodash' ;
import React from 'react' ;
import { Catch } from 'dome/errors' ;
import { Item } from 'dome/layout/dispatch' ;

import Ivette from '@ivette' ;

/**
   @class
   @summary Defines the plugin toolbar
   @description
   Shall be defined once inside main plugin rendering.
*/
export const PluginToolbar = ({children}) => (
  <Item id='ivette.toolbar.display'>
    <Catch label='Plugin Toolbar'>{ children }</Catch>
  </Item>
);

/**
   @class
   @summary Defines the plugin toolbar
   @description
   Shall be defined once inside main plugin rendering.
*/
export const PluginSidebar = ({children}) => (
  <Item id='ivette.sidebar.display'>
    <Catch label='Plugin Sidevar'>{ children }</Catch>
  </Item>
);

// --------------------------------------------------------------------------

export default { PluginSidebar, PluginToolbar };

// --------------------------------------------------------------------------
