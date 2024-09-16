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
  This package allow us to add a side panel inside the elements.

  The main element is SidePanel.
  This component needs two chidren :
  ```
  <SidePANEL>
    <PanelContent />
    <A />
  </SidePanel>
  ```
  "A" is the content that needs a sidePanel,
  the first child is the panel content.

  This package provide some components to creating the side panel content :
  * ListElement
  * Text
  * Actions

  @packageDocumentation
  @module dome/frame/sidePanel
 */

import { Label } from 'dome/controls/labels';
import React from 'react';
import { classes } from 'dome/misc/utils';


/* --------------------------------------------------------------------------*/
/* --- SidePanel Container                                                   */
/* --------------------------------------------------------------------------*/
interface SidePanelProps {
  className?: string;
  show?: boolean;
  position?: 'left' | 'right'
  children: [JSX.Element, JSX.Element];
}

export const SidePanel = (props: SidePanelProps): JSX.Element => {
  const { show = true, className, position } = props;
  const classContainer = 'dome-sidepanel-container';

  const classNames = classes(
    classContainer,
    position === 'left' ? classContainer+'-left' : classContainer+'-right',
    className,
  );
  const [A, panelContent] = props.children;

  return (
    <div className='dome-sidepanel'>
      { show &&
        <div className={classNames}>
          {panelContent}
        </div>
      }
      {A}
    </div>
  );
};

/* --------------------------------------------------------------------------*/
/* --- SidePanel List                                                        */
/* --------------------------------------------------------------------------*/
export interface ElementProps {
  label: string;
  onClickName?: () => void;
  content: JSX.Element;
}

const Element = (props: ElementProps): JSX.Element => {
  const { label, onClickName,  content } = props;

  const nameClasse = classes(
    'dome-sidepanel-element-name',
    onClickName && "action"
  );

  return (
    <div className='dome-sidepanel-element'>
      <div
        className={nameClasse}
        onClick={() => { if(onClickName) onClickName(); }}
      >{label}</div>
      <div className='dome-sidepanel-element-content'>
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
    <div className='dome-sidepanel-list'>
      { props.list.map((elt, k) => <Element
          key={k}
          {...elt}
        />)
      }
    </div>
  );
}

/* --------------------------------------------------------------------------*/
/* --- SidePanel Text                                                        */
/* --------------------------------------------------------------------------*/
interface TextProps {
  label: string;
  content?: string | JSX.Element;
}

export function Text(props: TextProps): JSX.Element {
  return (
    <div className='dome-sidepanel-text'>
      <Label>
        {props.label}
      </Label>
      {props.content}
    </div>
  );
}

/* --------------------------------------------------------------------------*/
/* --- SidePanel Button                                                      */
/* --------------------------------------------------------------------------*/
interface ActionsProps {
  children: React.ReactNode;
}

export function Actions(props: ActionsProps): JSX.Element {
  return (
    <div className='dome-sidepanel-actions'>
      {props.children}
    </div>
  );
}
