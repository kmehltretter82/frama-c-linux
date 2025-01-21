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
  @packageDocumentation
  @module dome/help
 */

import React from 'react';
import { IconButton } from './controls/buttons';
import { Modal, showModal } from './dialogs';
import { iconTag, Markdown, Pattern } from './text/markdown';

/* --------------------------------------------------------------------------*/
/* --- Help                                                                  */
/* --------------------------------------------------------------------------*/

interface HelpIconProps {
  /** icon size */
  size?: number;
  /** Tab of patterns */
  patterns?: Pattern[];
  /** Initial scroll to the chosen id */
  scrollTo?: string;
  /** Text of the label. Prepend to other children elements. */
  label: string;
  /** children */
  children: string;
}

export function HelpIcon(props: HelpIconProps): JSX.Element {
  const { size, patterns, scrollTo, label, children } = props;

  return (
    <IconButton
      icon='HELP'
      size={size}
      className='dome-xDoc-icon'
      title={'Help'}
      onClick={() => showModal(
        <Modal label= {label} >
          <Markdown
            patterns={patterns || [iconTag]}
            scrollTo={scrollTo}
          >{ children }</Markdown>
        </Modal>)
      }
    />
  );
}
