/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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
// --- Tabs
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/frame/tabs
*/

import React from 'react';
import { Icon } from 'dome/controls/icons';

import './style.css';

// --------------------------------------------------------------------------
// --- Tabs Bar
// --------------------------------------------------------------------------

export interface TabsBarProps {
  children?: React.ReactNode;
}

/** Container for Tabs. */
export function TabsBar(props: TabsBarProps) {
  return (
    <div className="dome-xTabsBar dome-color-frame">
      {props.children}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Single Tab
// --------------------------------------------------------------------------

export interface TabProps<A> {
  /** Tab's identifier. */
  value: A;
  /** Tab's label. */
  label?: string;
  /** Tab's tooltip text. */
  title?: string;
  /** Close tab's tooltip text. */
  closing?: string;
  /** Currently selected tab. */
  selection?: A;
  /** Selection callback. */
  onSelection?: (value: A) => void;
  /** Closing callback. */
  onClose?: (value: A) => void;
}

/** Tab Selector. */
export function Tab<A>(props: TabProps<A>) {
  const { value, selection, onSelection, onClose } = props;
  const selected = value === selection;
  // --- Tab Rendering
  const onSelect = onSelection && (() => onSelection(value));
  const onClosed = onClose && (() => onClose(value));
  const closing = onClose ? (
    <Icon
      className="dome-xTab-closing"
      title={props.closing || 'Close Tab'}
      id="CROSS"
      onClick={onClosed}
    />
  ) : undefined;
  const classes = `dome-xTab${selected ? ' dome-active' : ' dome-inactive'}`;
  return (
    <label
      className={classes}
      title={props.title}
      onClick={onSelect}
    >
      {props.label}
      {closing}
    </label>
  );
}

// --------------------------------------------------------------------------
