/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2025                                                */
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

/**
  This package allows us to add a panel inside positioned elements.

  It provides some components to create the panel content:
  * ListElement
  * Text
  * Actions

  @packageDocumentation
  @module dome/frame/Panel
 */

import React from 'react';
import { classes } from 'dome/misc/utils';
import { Hbox } from 'dome/layout/boxes';
import { Label } from 'dome/controls/labels';


/* --------------------------------------------------------------------------*/
/* --- Panel Container                                                       */
/* --------------------------------------------------------------------------*/

export type PanelPosition = 'top' | 'bottom' | 'left' | 'right';

interface PanelProps {
  /** Label. */
  label?: string;
  /** Icon. */
  icon?: string;
  /** Title. */
  title?: string;
  /** Actions : Add in the panel title */
  actions?: React.JSX.Element;
  /** Additional class. */
  className?: string;
  /** Position to displayed the panel. Default 'tr' */
  position?: PanelPosition;
  /** Defaults to `true`. */
  visible?: boolean;
  /** Defaults to `true`. */
  display?: boolean;
  /** Panel children. */
  children: JSX.Element;
}

export const Panel = (props: PanelProps): JSX.Element => {
  const { label, icon, title, actions, visible = true, display = true,
    className, position = 'right' } = props;

  const classNames = classes(
    'dome-xPanel',
    'dome-xPanel-'+position,
    visible ? 'dome-xPanel-open' : 'dome-xPanel-close',
    !display && 'dome-control-erased',
    className,
  );

  return (
    <div className={classNames}>
      { (label || icon || actions) &&
      <Hbox className={'dome-xPanelTitle'}>
        <Label icon={icon} label={label} title={title}/>
        { actions}
      </Hbox>
      }
      { props.children }
    </div>
  );
};

/* --------------------------------------------------------------------------*/
/* --- Panel List                                                            */
/* --------------------------------------------------------------------------*/
export interface ElementProps {
  /** Selection state. */
  selected?: boolean;
  /** Selection callback. */
  onSelection?: () => void;
  /** Item element. */
  children?: JSX.Element;
}

export function Element(props: ElementProps): JSX.Element {
  const { selected = true, onSelection, children } = props;

  const classNames = classes(
    'dome-xPanel-element',
    selected ? 'dome-active' : 'dome-inactive',
  );
  return (
    <div
      className={classNames}
      onClick={onSelection}
    >
      {children}
    </div>
  );
}

interface ListElementProps {
  children: JSX.Element[];
}

export function ListElement(props: ListElementProps): JSX.Element {
  return (
    <div className='dome-xPanel-list'>
      {props.children}
    </div>
  );
}
