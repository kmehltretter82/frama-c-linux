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

/** Labels support fowarding refs to their inner [<label/>] element. */
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
  /** Click event callback. */
  onClick?: (evt: React.MouseEvent) => void;
  /** Right-click event callback. */
  onContextMenu?: (evt: React.MouseEvent) => void;
}

const makeLabel = (className: string) => (props: LabelProps, ref: any) => {
  const { display = true } = props;
  const allClasses = classes(
    className,
    !display && 'dome-control-erased',
    props.className,
  );
  return (
    <label
      ref={ref}
      className={allClasses}
      title={props.title}
      style={props.style}
      onClick={props.onClick}
      onContextMenu={props.onContextMenu}
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
export const Label = React.forwardRef(makeLabel(LABEL));

/** Title and headings. */
export const Title = React.forwardRef(makeLabel(TITLE));

/** Description, textbook content. */
export const Descr = React.forwardRef(makeLabel(DESCR));

/** Selectable textual information. */
export const Data = React.forwardRef(makeLabel(TDATA));

/** Selectable inlined source-code content. */
export const Code = React.forwardRef(makeLabel(TCODE));

// --------------------------------------------------------------------------
