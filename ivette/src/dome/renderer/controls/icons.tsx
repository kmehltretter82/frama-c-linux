/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- SVG Icons
// --------------------------------------------------------------------------

/**
   You can [register](#.register) new icons or override existing ones
   and [iterate](#.forEach) over the icon base.

   [[include:icons.md]]

   @packageDocumentation
   @module dome/controls/icons
 */

import _ from 'lodash';
import React from 'react';
import { classes, styles } from 'dome/misc/utils';
import Gallery from './gallery.json';
import './style.css';

/* @ internal */
const Icons: { [id: string]: { viewBox?: string; path: string } } = Gallery;

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
  className?: string;
  fill?: string;
}

/**
   Low-level SVG icon.
   Only returns the identified `<svg/>` element from Icon base.
 */
export function SVG(props: SVGprops): null | JSX.Element {
  const { id, className, fill } = props;
  if (!id) return null;
  const icon = Icons[id];
  if (!icon) return <>{id}</>;
  const {
    title,
    size = 12,
    offset = _.floor(-size * 0.125),
  } = props;
  const { path, viewBox = '0 0 24 24' } = icon;
  return (
    <svg
      height={size}
      style={{ bottom: offset }}
      viewBox={viewBox}
      className={className}
    >
      {title && <title>{title}</title>}
      <path d={path} fill={fill} />
    </svg>
  );
}

// --------------------------------------------------------------------------
// --- Icon Component
// --------------------------------------------------------------------------

export type IconKind =
  'disabled' | 'selected' | 'positive' | 'negative' | 'warning' | 'default';

/** Icon Component Properties */
export interface IconProps extends SVGprops {
  /** Additional class name(s). */
  className?: string;
  /** Display (default is true). */
  display?: boolean;
  /** Visibility (default is true). */
  visible?: boolean;
  /** Additional DIV style. */
  style?: React.CSSProperties;
  /** Fill style property. */
  fill?: string;
  /** Icon Kind. */
  kind?: IconKind;
  /** Click callback. */
  onClick?: (event: React.MouseEvent<HTMLDivElement>) => void;
  /** Right-Click callback. */
  onContextMenu?: (event: React.MouseEvent<HTMLDivElement>) => void;
}

/**
   Icon Component.
   Consult the [Icon Gallery](../guides/icons.md.html) for default icons.
 */
export function Icon(props: IconProps): JSX.Element {
  const {
    id, title, fill, kind='default',
    size, className, offset, style,
    visible = true, display = true,
    onClick, onContextMenu,
  } = props;
  const divClass = classes(
    'dome-xIcon', `dome-xIcon-${kind}`,
    !visible && 'dome-control-hidden',
    !display && 'dome-control-erased',
    className
  );
  const divStyle = styles(fill && { fill }, style);
  return (
    <div
      className={divClass}
      style={divStyle}
      onClick={onClick}
      onContextMenu={onContextMenu}
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
export function Badge(props: BadgeProps): JSX.Element {
  const { value, title, onClick } = props;
  let content;
  if (typeof value === 'string' && Icons[value]) {
    content = <Icon id={value} size={10} />;
  } else {
    const style =
      (typeof (value) === 'number' && value < 10) ||
        (typeof (value) === 'string' && value.length === 1) ?
        { paddingLeft: 2, paddingRight: 2 } : {};
    content = <label style={style} className="dome-text-label">{value}</label>;
  }
  return (
    <div
      className="dome-xBadge"
      title={title}
      onClick={onClick}
    >
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
export function register(icon: CustomIcon): void {
  const { id, ...jsicon } = icon;
  Icons[id] = jsicon;
}

export interface IconData extends CustomIcon {
  section?: string;
  title?: string;
}

/**
   Iterate over icons gallery.
   See [[register]] to add custom icons to the gallery.
 */
export function forEach(fn: (ico: IconData) => void): void {
  const ids = Object.keys(Icons);
  ids.forEach((id) => {
    const jsicon = Icons[id];
    fn({ id, ...jsicon });
  });
}

// --------------------------------------------------------------------------
