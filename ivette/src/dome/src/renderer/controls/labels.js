// --------------------------------------------------------------------------
// --- Labels
// --------------------------------------------------------------------------

/** @module dome/controls/labels */

import React from 'react' ;
import { Icon } from './icons' ;
import './style.css' ;

// --------------------------------------------------------------------------
// --- Generic Label
// --------------------------------------------------------------------------

const addClass = (a,b) => b ? a + ' ' + b : a ;

const makeLabel = (className,props) => {
  const { display=true } = props ;
  const allClasses =
        className +
        (display ? ' ' : ' dome-control-erased ') +
        (props.className || '');
  return (
    <label className={allClasses}
           title={props.title}
           style={props.style} >
      {props.icon && <Icon title={props.title} id={props.icon}/>}
      {props.label}
      {props.text}
      {props.children}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- CSS Classes
// --------------------------------------------------------------------------

const LABEL = "dome-xLabel dome-text-label" ;
const TITLE = "dome-xLabel dome-text-title" ;
const DESCR = "dome-xLabel dome-text-descr" ;
const TDATA = "dome-xLabel dome-text-data" ;
const TCODE = "dome-xLabel dome-text-code" ;

// --------------------------------------------------------------------------
// --- Components
// --------------------------------------------------------------------------

/**
   @summary Component labels.
   @property {string} [label] - Textual content (prepend to children components, if any)
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Label tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
*/
export const Label = (props) => makeLabel(LABEL,props);

/**
   @summary Title and headings.
   @property {string} [label] - Textual content (prepend to children components, if any)
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Label tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
*/
export const Title = (props) => makeLabel(TITLE,props);

/**
   @summary Description, textbook content.
   @property {string} [label] - Textual content (prepend to children components, if any)
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Label tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
*/
export const Descr = (props) => makeLabel(DESCR,props);

/**
   @summary Selectable textual information.
   @property {string} [label] - Textual content (prepend to children components, if any)
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Label tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
*/
export const Data = (props) => makeLabel(TDATA,props);

/**
   @summary Selectable inlined source-code content.
   @property {string} [text] - Textual content (prepend to children components, if any)
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Label tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
*/
export const Code = (props) => makeLabel(TCODE,props);

// --------------------------------------------------------------------------
