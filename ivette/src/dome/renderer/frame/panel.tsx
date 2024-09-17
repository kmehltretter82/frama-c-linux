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

/**
  This package allows us to add a panel inside positioned elements.

  It provides some components to create the panel content:
  * ListElement
  * Text
  * Actions

  @packageDocumentation
  @module dome/frame/Panel
 */

import { Label } from 'dome/controls/labels';
import React from 'react';
import { classes } from 'dome/misc/utils';


/* --------------------------------------------------------------------------*/
/* --- Panel Container                                                       */
/* --------------------------------------------------------------------------*/
interface PanelProps {
  className?: string;
  show?: boolean;
  position?: 'left' | 'right'
  children: JSX.Element[];
}

export const Panel = (props: PanelProps): JSX.Element => {
  const { show = true, className, position } = props;

  const classNames = classes(
    'dome-xPanel',
    position === 'left' ? 'dome-xPanel-left' : 'dome-xPanel-right',
    show ? 'dome-xPanel-open' : 'dome-xPanel-close',
    className,
  );

  return (
    <div className={classNames}>
      {props.children}
    </div>
  );
};

/* --------------------------------------------------------------------------*/
/* --- Panel List                                                            */
/* --------------------------------------------------------------------------*/
export interface ElementProps {
  label: string;
  onClickName?: () => void;
  content: JSX.Element;
}

const Element = (props: ElementProps): JSX.Element => {
  const { label, onClickName,  content } = props;

  const nameClasse = classes(
    'dome-xPanel-element-name',
    onClickName && "action"
  );

  return (
    <div className='dome-xPanel-element'>
      <div
        className={nameClasse}
        onClick={() => { if(onClickName) onClickName(); }}
      >{label}</div>
      <div className='dome-xPanel-element-content'>
        {content}
      </div>
    </div>
  );
};

interface ListElementProps {
  list: ElementProps[];
}

export function ListElement(props: ListElementProps): JSX.Element {
  return (
    <div className='dome-xPanel-list'>
      { props.list.map((elt, k) => <Element
          key={k}
          {...elt}
        />)
      }
    </div>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Panel Text                                                            */
/* --------------------------------------------------------------------------*/
interface TextProps {
  label: string;
  content?: string | JSX.Element;
}

export function Text(props: TextProps): JSX.Element {
  return (
    <div className='dome-xPanel-text'>
      <Label>
        {props.label}
      </Label>
      {props.content}
    </div>
  );
}

/* --------------------------------------------------------------------------*/
/* ---Panel Button                                                           */
/* --------------------------------------------------------------------------*/
interface ActionsProps {
  children: React.ReactNode;
}

export function Actions(props: ActionsProps): JSX.Element {
  return (
    <div className='dome-xPanel-actions'>
      {props.children}
    </div>
  );
}
