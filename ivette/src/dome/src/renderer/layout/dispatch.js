// --------------------------------------------------------------------------
// --- Dispatch Layout
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/layout/dispatch
   @description

   This module allows to declare components anywhere in a component hierarchy
   and to render them a totally different place.

   You shall wrap dispatched components inside a `<Dispatch.Item>` container,
   and render them wherever you want with `<Dispatch.Render>`. Each target
   place can display only one uniquely identified item.

   This can be also used to display some item among many in one unique place.
*/

import _ from 'lodash' ;
import React from 'react';
import { emitter } from 'dome/system';
import * as Dome from 'dome' ;

// --------------------------------------------------------------------------
// --- Global Dispatcher
// --------------------------------------------------------------------------

const EVENT = (id) => 'dome.dispatch.' + id ;
const ITEMS = {};

const getItem = (id) => {
  let item = ITEMS[id];
  if (!item) item = ITEMS[id] = {
    id, evt: EVENT(id)
  };
  return item;
};

const trigger = (item) => {
  if (item.rendered) {
    item.rendered = false ;
    setImmediate(() => emitter.emit(item.evt));
  }
};

const setItem = (id,children) => {
  let item = getItem(id);
  item.content = children ;
  trigger(item);
};

const removeItem = (id) => {
  let item = getItem(id);
  item.content = null ;
  trigger(item);
};

// --------------------------------------------------------------------------
// --- Dispatched Items
// --------------------------------------------------------------------------

/**
   @summary Define dispatched item.
   @property {string} id - the item _global_ unique identifier
   @property {React.Children} {children} - item contents
   @description
   Declare the content of some dispatched item.
   Each item identifier shall be assigned once from the mounted
   hierarchy of components. Otherwize, the content that would be
   displayed is totally unpredictable.
*/
export function Item({ id, children })
{
  React.useEffect(() => {
    setItem(id,children);
    return () => removeItem(id);
  });
  return null;
}

// --------------------------------------------------------------------------
// --- Render Targets
// --------------------------------------------------------------------------

/**
   @summary Render dispatched item.
   @property {string} id - the item _global_ unique identifier to render
   @property {function|React.Children} {children} - conditional or alternative content (default: `null`)
   @description
   Render the content of some dispatched item.
   In case multiple of rendering, the children elements would be shared
   among several places, with unpredicatable behavior.

   If the render element has a function as children, it is passed the content of the
   item, or undefined. This allows for conditional rendering, depending on whether the item
   has been specified somewhere in the hierarchy or not.

   Otherwized, when the item is not specified, the render element display
   its own content, if any.
*/
export function Render({ id, children=null })
{
  const [ age, setAge ] = React.useState(0);
  React.useEffect(() => {
    const evt = EVENT(id);
    const fn = () => setAge(age+1);
    emitter.on(evt,fn);
    return () => emitter.off(evt,fn);
  });
  let item = getItem(id);
  item.rendered = true ;
  if (typeof(children)==='function')
    return children(item.content);
  else {
    let content = item.content || children ;
    return content && <React.Fragment>{content}</React.Fragment>;
  }
}

// --------------------------------------------------------------------------
