// --------------------------------------------------------------------------
// --- SVG Icons
// --------------------------------------------------------------------------

/**
   Consult the [Icon Gallery](../guides/icons.md.html) for default icons.
   You can [register](#.register) new icons or override existing ones
   and [iterate](#.forEach) over the icon base.
   @packageDocumentation
   @module dome/controls/icons
 */

import _ from 'lodash';
import React from 'react';
import Gallery from './gallery.json';
import './style.css';

/*@ internal */
const Icons: { [id: string]: { viewBox?: string, path: string } } = Gallery;

// --------------------------------------------------------------------------
// --- Raw SVG element
// --------------------------------------------------------------------------

export interface SVGprops {
  /** Icon's identifier. */
  id: string;
  /** Icon's tool-tip. */
  title?: string;
  /** Icon's dimension in pixels (default: `12`). */
  size?: number;
  /**
     Vertical alignement offset, in pixels.
     Default is set to `-0.125` times the size).
   */
  offset?: number;
}

/**
   Low-level SVG icon.
   Only returns the identified `<svg/>` element from Icon base.
 */
export function SVG(props: SVGprops): null | JSX.Element {
  const { id } = props;
  if (!id) return null;
  const icon = Icons[id];
  if (!icon) return <>{id}</>;
  const {
    title,
    size = 12,
    offset = _.floor(- size * 0.125),
  } = props;
  const { path, viewBox = "0 0 24 24" } = icon;
  return (
    <svg
      height={size}
      width={size}
      style={{ bottom: offset }}
      viewBox={viewBox}
    >
      {title && <title>{title}</title>}
      <path d={path} />
    </svg>
  );
}

// --------------------------------------------------------------------------
// --- Icon Component
// --------------------------------------------------------------------------

/** Icon Component Properties */
export interface IconProps extends SVGprops {
  /** Additional class name(s). */
  className?: string;
  /** Additional DIV style. */
  style?: React.CSSProperties;
  /** Fill style property. */
  fill?: string;
  /** Click callback. */
  onClick?: (event?: React.MouseEvent) => void;
}

/**
   Icon Component.
   Consult the [Icon Gallery](../guides/icons.md.html) for default icons.
 */
export function Icon(props: IconProps) {
  const { id, title, onClick, fill, size, className = '', offset, style } = props;
  const divClass = 'dome-xIcon ' + className;
  const divStyle = fill ? { fill, ...style } : style;
  return (
    <div
      className={divClass}
      style={divStyle}
      onClick={onClick}
    >
      <SVG id={id} size={size} title={title} offset={offset} />
    </div>
  );
}

// --------------------------------------------------------------------------
// ---  Badge Component
// --------------------------------------------------------------------------

/** Badge Properties */
export interface BadgeProps {
  /**
     Displayed value.
     Can be a number, a single letter, or an icon identifier.
   */
  value: number | string;
  /** Badge tool-tip. */
  title?: string;
  /** Click callback. */
  onClick?: (event?: React.MouseEvent) => void;
}

/**
   Rounded icon, number or letter.
   Depending on the type of value, display either a number,
   a label, or the corresponding named icon.
   Consult the [Icon Gallery](gallery-icons.html) for default icons.
 */
export function Badge(props: BadgeProps) {
  const { value, title, onClick } = props;
  let content;
  if (typeof value === 'string' && Icons[value]) {
    content = <Icon id={value} size={10} />;
  } else {
    const style =
      (typeof (value) === 'number' && value < 10) ||
        (typeof (value) === 'string' && value.length == 1) ?
        { paddingLeft: 2, paddingRight: 2 } : {};
    content = <label style={style} className='dome-text-label'>{value}</label>;
  }
  return (
    <div className="dome-xBadge"
      title={title} onClick={onClick}>
      {content}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Icon Database
// --------------------------------------------------------------------------

/** Custom Icon Properties */
export interface CustomIcon {
  /** Icon identifier. */
  id: string;
  /** Icon's viewBox (default is `"0 0 24 24"`). */
  viewBox?: string;
  /** Icon's SVG path. */
  path: string;
}

/**
   Register a new custom icon.
 */
export function register(icon: CustomIcon) {
  const { id, ...jsicon } = icon;
  Icons[id] = jsicon;
}

/**
   Iterate over icons gallery.
   See [[register]] to add custom icons to the gallery.
 */
export function forEach(fn: (ico: CustomIcon) => void) {
  for (let id in Icons) {
    const jsicon = Icons[id];
    fn({ id, ...jsicon });
  }
}

// --------------------------------------------------------------------------
