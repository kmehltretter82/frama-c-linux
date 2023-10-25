/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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

import React, { CSSProperties } from 'react';
import { classes } from 'dome/misc/utils';
import * as CS from '@codemirror/state';
import * as CM from '@codemirror/view';

/* -------------------------------------------------------------------------- */
/* --- Basic Definitions                                                  --- */
/* -------------------------------------------------------------------------- */

export interface Range { offset: number; length: number }
export interface Position { offset: number; line: number }
export interface Selection extends Range { fromLine: number, toLine: number }

export function byDepth(a : Range, b : Range): number
{
  return (a.length - b.length) || (b.offset - a.offset);
}

/* -------------------------------------------------------------------------- */
/* --- Editor View                                                        --- */
/* -------------------------------------------------------------------------- */

function createView(parent: Element): CM.EditorView {
  const extensions : CS.Extension[] = [
    //CS.EditorState.readOnly.of(false),
  ]
  const state = CS.EditorState.create({ extensions });
  return new CM.EditorView({ state, parent });
}

/* -------------------------------------------------------------------------- */
/* --- Rich Text Component                                                --- */
/* -------------------------------------------------------------------------- */

export interface RichTextProps {
  className?: string;
  style?: CSSProperties;
}

export function RichText(props: RichTextProps) : JSX.Element {
  type View = CM.EditorView | null;
  const parent = React.useRef(null);
  const editor = React.useRef<View>(null);
  React.useEffect(() => {
    const div = parent.current;
    if (!div) return;
    const view = createView(div);
    editor.current = view;
    return () => {
      editor.current = null;
      view.destroy();
    };
  }, []);
  const className = classes(
    'cm-global-box',
    props.className
  );
  return <div className={className} style={props.style} ref={parent} />;
}

/* -------------------------------------------------------------------------- */
