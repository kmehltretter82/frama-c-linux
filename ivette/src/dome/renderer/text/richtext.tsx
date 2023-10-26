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
/* --- Text Buffer                                                        --- */
/* -------------------------------------------------------------------------- */

type View = CM.EditorView | null;

function appendContents(view: CM.EditorView, text: string): void {
  const length = view.state.doc.length;
  view.dispatch({ changes: { from: length, insert: text } });
}

function dispatchContents(view: CM.EditorView, text: string): void {
  const length = view.state.doc.length;
  view.dispatch({ changes: { from: 0, to: length, insert: text } });
}

/**
   Text contents of a RichText component.

   This class can be used as a proxy to a the content of a {RichText}
   component. Using the methods of the class, you can update or dump the
   contents edited/viewed by the associated component.

   At most one component shall be associated with a given Text buffer at the
   same time.

   All methods are bound to `this`.
 */
export class TextProxy {

  // --- Private part

  private buffer = '';
  private proxy : View = null;

  constructor() {
    this.clear = this.clear.bind(this);
    this.append = this.append.bind(this);
    this.toString = this.toString.bind(this);
    this.setContents = this.setContents.bind(this);
    this.connect = this.connect.bind(this);
  }

  /** @ignore */
  connect(newView: View): void {
    const oldView = this.proxy;
    if (oldView) {
      this.proxy = null;
      this.buffer = oldView.state.doc.toString();
    }
    if (newView) {
      dispatchContents(newView, this.buffer);
      this.proxy = newView;
      this.buffer = '';
    }
  }

  // --- Public part

  clear(): void {
    const view = this.proxy;
    if (view) dispatchContents(view, '');
    else this.buffer = '';
  }

  toString(): string {
    const view = this.proxy;
    return view ? view.state.doc.toString() : this.buffer;
  }

  append(text: string): void {
    const view = this.proxy;
    if (view) appendContents(view, text);
    else this.buffer += text;
  }

  setContents(text: string): void {
    const view = this.proxy;
    if (view) dispatchContents(view, text);
    else this.buffer = text;
  }

}

/* -------------------------------------------------------------------------- */
/* --- Code Mirror Extensions                                             --- */
/* -------------------------------------------------------------------------- */

class Extension {
  readonly extension : CS.Extension[] = [];
  pack(ext : CS.Extension): void { this.extension.push(ext); }
}

class Field<A> extends Extension {
  readonly field : CS.StateField<A>;
  private readonly annot : CS.AnnotationType<A>;

  constructor(init: A) {
    super();
    const annot = CS.Annotation.define<A>();
    const field = CS.StateField.define<A>({
      create: () => init,
      update: (fd: A, tr: CS.Transaction) => tr.annotation(annot) ?? fd,
    });
    this.annot = annot;
    this.field = field;
    this.pack(field);
  }

  dispatch(view: View, value: A): void {
    view?.dispatch({ annotations: this.annot.of(value) });
  }

}

/* -------------------------------------------------------------------------- */
/* --- Read Only                                                          --- */
/* -------------------------------------------------------------------------- */

const ReadOnly = new Field(false);

ReadOnly.pack(CS.EditorState.readOnly.from(ReadOnly.field));

/* -------------------------------------------------------------------------- */
/* --- Change Listener                                                    --- */
/* -------------------------------------------------------------------------- */

export type Callback = () => void;

const OnChange = new Field<Callback|null>(null);

OnChange.pack(
  CM.EditorView.updateListener.computeN(
    [OnChange.field],
    (state) => {
      const callback = state.field(OnChange.field);
      if (callback !== null)
        return [
          (updates: CM.ViewUpdate) => {
            if (!updates.changes.empty) callback();
          }
        ];
      return [];
    }
));

/* -------------------------------------------------------------------------- */
/* --- Editor View                                                        --- */
/* -------------------------------------------------------------------------- */

function createView(parent: Element): CM.EditorView {
  const extensions : CS.Extension[] = [
    ReadOnly,
    OnChange,
  ];
  const state = CS.EditorState.create({ extensions });
  return new CM.EditorView({ state, parent });
}

/* -------------------------------------------------------------------------- */
/* --- Rich Text Component                                                --- */
/* -------------------------------------------------------------------------- */

export interface RichTextProps {
  text?: TextProxy;
  readOnly?: boolean;
  onChange?: Callback;
  display?: boolean;
  visible?: boolean;
  className?: string;
  style?: CSSProperties;
}

export function TextView(props: RichTextProps) : JSX.Element {
  const [view, setView] = React.useState<View>(null);

  // --- text
  const { text } = props;
  React.useEffect(() => {
    if (text) {
      text.connect(view);
      if (view) return () => text.connect(null);
    }
    return undefined;
  }, [text, view]);

  // ---- readOnly, onChange
  const { readOnly = false, onChange = null } = props;
  React.useEffect(() => ReadOnly.dispatch(view, readOnly), [view, readOnly]);
  React.useEffect(() => OnChange.dispatch(view, onChange), [view, onChange]);

  // ---- Mount & Unmount Editor
  const [nodeRef, setRef] = React.useState<Element | null>(null);
  React.useEffect(() => {
    if (!nodeRef) return;
    const view = createView(nodeRef);
    setView(view);
    return () => { setView(null); view.destroy(); };
  }, [nodeRef]);

  // ---- Editor DIV
  const { visible=true, display=true } = props;
  const className = classes(
    'cm-global-box',
    !display && 'dome-erased',
    !visible && 'dome-hidden',
    props.className,
  );
  return <div className={className} style={props.style} ref={setRef} />;
}

/* -------------------------------------------------------------------------- */
