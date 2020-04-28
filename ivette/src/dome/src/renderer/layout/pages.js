// --------------------------------------------------------------------------
// --- Text Pages
// --------------------------------------------------------------------------

/**
   @module dome/layout/pages
   @description
   A collection of text area and elements do render textual content.

   Inside such areas, all elements are styled like a classical web page.
   All elements are encapsulated inside a `<div>` with `'dome-pages'`
   class name, which can be used in your CSS selectors.

   All the textual parts are selectable inside the page, contrarily to
   most other widget components.

   The behaviour of `<a href=...>` elements differs for local links and external URLs.
   Local links trigger a ['dome.href'](dome_.html#~event:'dome.href') event, that
   you can listen to from the originating renderer process, _eg. by using `Dome.useUpdate()`
   custom hook.

   External links launch the user's default browser.

*/

import React from 'react' ;
import { AutoSizer } from 'react-virtualized' ;
import './pages.css' ;

// --------------------------------------------------------------------------
// --- Page
// --------------------------------------------------------------------------

/**
   @property {object} [style] - additional style elements
   @property {Elements} [children] - page content
   @summary a blank HTML page
   @description

   The page has insets and shadows and fills the entire available area.
   Large content is crolled inside in both directions.
*/

export const Page = ({style,children}) => {
  return (
    <div className='dome-xPages-page'>
      <div className='dome-xPages-sheet dome-pages'>
        {children}
      </div>
    </div>
  );
};

// --------------------------------------------------------------------------
// --- Page
// --------------------------------------------------------------------------

/**
   @property {object} [style] - additional style elements
   @property {Elements} [children] - page content
   @summary a blank HTML textarea
   @description

   The area has small padding and no margin, and does not scroll its content.
*/

export const Note = ({style,children}) => (
  <div className=' dome-xPages-note dome-pages' style={style}>
    {children}
  </div>
);

// --------------------------------------------------------------------------
// Export Default
// --------------------------------------------------------------------------

export default { Page, Note };

// --------------------------------------------------------------------------
