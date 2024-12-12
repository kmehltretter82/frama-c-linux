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
  @packageDocumentation
  @module dome/help
 */

import React from 'react';
import { classes } from 'dome/misc/utils';
import { IconButton, IconButtonKind } from './controls/buttons';
import { Modal, showModal, ModalProps } from './dialogs';
import { iconTag, Markdown, Pattern } from './text/markdown';

/* --------------------------------------------------------------------------*/
/* --- Panel List                                                            */
/* --------------------------------------------------------------------------*/
interface HelpMarkdownProps {
  /** classes for Doc component */
  className?: string;
  /** Tab of patterns */
  patterns?: Pattern[];
  /**
   * scroll to title h1 or h2 when component is render.
   * The value must be the id of the balise html.
   * Id is calculate by title.toLowerCase().replaceAll(' ','-')
   * where title is the content of h1 or h2 if it is a string
  */
  initialScrollTo?: string;
  /** Markdown content. */
  children?: string;
}

export function HelpMarkdown(props: HelpMarkdownProps): JSX.Element {
  const { patterns = [iconTag], className, initialScrollTo, children } = props;
  const classNames = classes('dome-xHelp', className);

  const scrollableDivRef = React.useRef<HTMLDivElement>(null);
  const anchorsRef = React.useRef<{
    [key: string] : HTMLHeadingElement | null
  }>({});

  const scrollToAnchor = (id: string): void => {
    const scrollableDiv = scrollableDivRef.current;
    const anchor = anchorsRef.current[id];
    const top = scrollableDiv?.offsetTop || 0;

    if (scrollableDiv && anchor) {
      const anchorPosition = anchor.offsetTop - top;
      scrollableDiv.scrollTo({
        top: anchorPosition,
        behavior: 'smooth',
      });
    }
  };

  React.useEffect(() => {
    if(initialScrollTo) scrollToAnchor(initialScrollTo);
  }, [initialScrollTo]);

  return (
    <div ref={scrollableDivRef} className={classNames}>
      <Markdown
        patterns={patterns || [iconTag]}
        anchorsRef={anchorsRef}
      >{ children }</Markdown>
    </div>
  );
}

interface IconModalMdProps extends HelpMarkdownProps {
  /** Icon props */
  kind?: IconButtonKind;
  title?: string;
  size?: number;
  /** Properties of Modal component */
  modal: Omit<ModalProps, 'children'>;
}

export function IconHelpModalMd(props: IconModalMdProps): JSX.Element {
  const { title, kind, size,
    patterns, initialScrollTo,
    modal, children
  } = props;

  return (
    <IconButton
      icon='HELP'
      className='dome-xDoc-icon'
      title={title}
      kind={kind}
      size={size}
      onClick={() => showModal(
        <Modal {...modal} >
          <HelpMarkdown
            patterns={patterns}
            initialScrollTo={initialScrollTo}
          >{ children }</HelpMarkdown>
        </Modal>)
      }
    />
  );
}
