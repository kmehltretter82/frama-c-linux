// --------------------------------------------------------------------------
// --- Labels
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/controls/labels
*/

import React from 'react';
import { classes } from 'dome/misc/utils';
import { Icon } from './icons';
import './style.css';

// --------------------------------------------------------------------------
// --- Generic Label
// --------------------------------------------------------------------------

export interface LabelProps {
  /** Text of the label. Prepend to other children elements. */
  label?: string;
  /** Icon identifier. Displayed on the left side of the label. */
  icon?: string;
  /** Tool-tip description. */
  title?: string;
  /** Additional class. */
  className?: string;
  /** Additional style. */
  style?: React.CSSProperties;
  /** If `false`, do not display the label. Default to `true`. */
  display?: boolean;
  /** Additional content of the `<label/>` element. */
  children?: React.ReactNode;
}

const makeLabel = (className: string, props: LabelProps) => {
  const { display = true } = props;
  const allClasses = classes(
    className,
    !display && 'dome-control-erased',
    props.className,
  );
  return (
    <label
      className={allClasses}
      title={props.title}
      style={props.style}
    >
      {props.icon && <Icon title={props.title} id={props.icon} />}
      {props.label}
      {props.children}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- CSS Classes
// --------------------------------------------------------------------------

const LABEL = 'dome-xLabel dome-text-label';
const TITLE = 'dome-xLabel dome-text-title';
const DESCR = 'dome-xLabel dome-text-descr';
const TDATA = 'dome-xLabel dome-text-data';
const TCODE = 'dome-xLabel dome-text-code';

// --------------------------------------------------------------------------
// --- Components
// --------------------------------------------------------------------------

/** Simple labels. */
export const Label = (props: LabelProps) => makeLabel(LABEL, props);

/** Title and headings. */
export const Title = (props: LabelProps) => makeLabel(TITLE, props);

/** Description, textbook content. */
export const Descr = (props: LabelProps) => makeLabel(DESCR, props);

/** Selectable textual information. */
export const Data = (props: LabelProps) => makeLabel(TDATA, props);

/** Selectable inlined source-code content. */
export const Code = (props: LabelProps) => makeLabel(TCODE, props);

// --------------------------------------------------------------------------
