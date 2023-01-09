/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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

import React from 'react';

import { EditorState, StateField, Facet, Extension } from '@codemirror/state';
import { Annotation, Transaction, RangeSet } from '@codemirror/state';

import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { DOMEventMap as EventMap } from '@codemirror/view';
import { GutterMarker, gutter } from '@codemirror/view';
import { showTooltip, Tooltip } from '@codemirror/view';
import { DecorationSet } from '@codemirror/view';
import { lineNumbers } from '@codemirror/view';

import { parser } from '@lezer/cpp';
import { tags } from '@lezer/highlight';
import { SyntaxNode } from '@lezer/common';
import * as Language from '@codemirror/language';

import './style.css';

export type { Extension } from '@codemirror/state';
export { GutterMarker } from '@codemirror/view';
export { Decoration } from '@codemirror/view';
export { RangeSet } from '@codemirror/state';



// -----------------------------------------------------------------------------
//  CodeMirror state's extensions types definitions
// -----------------------------------------------------------------------------

// Helper types definitions.
export type Range = { from: number, to: number };
export type Get<A> = (state: EditorState | undefined) => A;
export type Set<A> = (view: EditorView | null, value: A) => void;
export interface Data<A, S> { init: A, get: Get<A>, structure: S }

// Event handlers type definition.
export type Handler<I, E> = (i: I, v: EditorView, e: E) => void;
export type Handlers<I> = { [e in keyof EventMap]?: Handler<I, EventMap[e]> };

// A Field is a data added to the CodeMirror internal state that can be
// modified by the outside world and used by plugins. The typical use case is
// when one needs to inject information from the server into the CodeMirror
// component. A Field exposes a getter and a setter that handles all React's
// hooks shenanigans. It also exposes a StateField, a CodeMirror data structure
// representing the internal state's part responsible of the data. This
// structure is exposed for two reasons. The first one is that it contains the
// extension that must be added to the CodeMirror instanciation. The second one
// is that it is needed during the Aspects creation's process.
export interface Field<A> extends Data<A, StateField<A>> { set: Set<A> }

// An Aspect is a data associated with an editor state and computed by combining
// data from several fields. A typical use case is if one needs a data that
// relies on a server side information (like a synchronized array) which must be
// recomputed each time the selection (which is a field but is also an internal
// information of CodeMirror) is changed. An Aspect exposes a getter that
// handles all React's hooks shenanigans and an extension that must be added to
// the CodeMirror initial configuration.
export interface Aspect<A> extends Data<A, Facet<A, A>> { extension: Extension }

// State extensions and Aspects have to declare their dependencies, i.e. the
// Field and Aspects they rely on to perform their computations. Dependencies
// are declared as a record mapping names to either a Field or an Aspect. This
// is needed to be able to give the dependencies values to the computing
// functions in a typed manner. However, an important point to take into
// consideration is that the extensions constructors defined below cannot
// actually typecheck without relying on type assertions. It means that if you
// declare an extension's dependencies after creating the extension, it will
// crash at execution time. So please, check that every dependency is declared
// before being used.
export type Dict = Record<string, unknown>;
export type Dependency<A> = Field<A> | Aspect<A>;
export type Dependencies<I extends Dict> = { [K in keyof I]: Dependency<I[K]> };



// -----------------------------------------------------------------------------
//  Internal types and helpers
// -----------------------------------------------------------------------------

// Type aliases to shorten internal definitions.
type Dep<A> = Dependency<A>;
type Deps<I extends Dict> = Dependencies<I>;
type Combine<Output> = (l: readonly Output[]) => Output;

// Helper function used to map a function over Dependencies.
type Mapper<I extends Dict, A> = (d: Dep<I[typeof k]>, k: string) => A;
function mapDict<I extends Dict, A>(deps: Deps<I>, fn: Mapper<I, A>): A[] {
  return Object.keys(deps).map((k) => fn(deps[k], k));
}

// Helper function used to transfrom a Dependencies will keeping its structure.
type Transform<I extends Dict> = (d: Dep<I[typeof k]>, k: string) => unknown;
function transformDict<I extends Dict>(deps: Deps<I>, tr: Transform<I>): Dict {
  return Object.fromEntries(Object.keys(deps).map(k => [k, tr(deps[k], k)]));
}

// Helper function retrieving the current values associated to each dependencies
// in a given editor state. They are returned as a Dict instead of the precise
// type because of TypeScript subtyping shenanigans that prevent us to correctly
// type the returned record. Thus, a type assertion has to be used.
function inputs<I extends Dict>(ds: Deps<I>, s: EditorState | undefined): Dict {
  return transformDict(ds, (d) => d.get(s));
}

// Helper function retrieving a dependency extension.
function getExtension<A>(dep: Dependency<A>): Extension {
  type Dep<A> = Dependency<A>;
  const asExt = (d: Dep<A>): boolean => Object.keys(d).includes('extension');
  const isAspect = (d: Dep<A>): d is Aspect<A> => asExt(d);
  if (isAspect(dep)) return dep.extension;
  else return dep.structure.extension;
}



// -----------------------------------------------------------------------------
//  CodeMirror state's extensions
// -----------------------------------------------------------------------------

// Several extensions constructors are provided. Each one of them encapsulates
// its dependencies if needed. This means that adding an extension to the
// CodeMirror's initial configuration will also add all its dependencies'
// extensions, and thus recursively. However, for now, there is no systemic way
// to check that the fields at the root of the dependencies tree are updated by
// a component. This means you have to verify, by hands, that every field is
// updated when needed by your component. It may be possible to compute a
// function that asks for a value for each fields in the dependencies tree and
// does the update for you, thus forcing you to actually update every fields.
// But it seems hard to define and harder to type.

// A Field is simply declared using an initial value. However, to be able to
// use it, you must add its extension (obtained through <field.extension>) to
// the CodeMirror initial configuration. If determining equality between
// values of the given type cannot be done using (===), an equality test can be
// provided through the optional parameters <equal>. Providing an equality test
// for complex types can help improve performances by avoiding recomputing
// extensions depending on the field.
export function createField<A>(init: A): Field<A> {
  const annot = Annotation.define<A>();
  const create = (): A => init;
  type Update<A> = (current: A, transaction: Transaction) => A;
  const update: Update<A> = (current, tr) => tr.annotation(annot) ?? current;
  const field = StateField.define<A>({ create, update });
  const get: Get<A> = (state) => state?.field(field) ?? init;
  const useSet: Set<A> = (v, a) =>
    React.useEffect(() => v?.dispatch({ annotations: annot.of(a) }), [v, a]);
  return { init, get, set: useSet, structure: field };
}

// An Aspect is declared using its dependencies and a function. This function's
// input is a record containing, for each key of the dependencies record, a
// value of the type of the corresponding field. The function's output is a
// value of the aspect's type.
export function createAspect<I extends Dict, O>(
  deps: Dependencies<I>,
  fn: (input: I) => O,
): Aspect<O> {
  const enables = mapDict(deps, getExtension);
  const init = fn(transformDict(deps, (d) => d.init) as I);
  const combine: Combine<O> = (l) => l.length > 0 ? l[l.length - 1] : init;
  const facet = Facet.define<O, O>({ combine, enables });
  const get: Get<O> = (state) => state?.facet(facet) ?? init;
  const convertedDeps = mapDict(deps, (d) => d.structure);
  const compute: Get<O> = (s) => fn(inputs(deps, s) as I);
  const extension = facet.compute(convertedDeps, compute);
  return { init, get, structure: facet, extension };
}

// A Decorator is an extension that adds decorations to the CodeMirror's
// document, i.e. it tags subpart of the document with CSS classes. See the
// CodeMirror's documentation on Decoration for further details.
export function createDecorator<I extends Dict>(
  deps: Dependencies<I>,
  fn: (inputs: I, state: EditorState) => DecorationSet
): Extension {
  const enables = mapDict(deps, getExtension);
  const get = (s: EditorState): DecorationSet => fn(inputs(deps, s) as I, s);
  class S { s: DecorationSet = RangeSet.empty; }
  class D extends S { update(u: ViewUpdate): void { this.s = get(u.state); } }
  const decorations = (d: D): DecorationSet => d.s;
  return enables.concat(ViewPlugin.fromClass(D, { decorations }));
}

// A Gutter is an extension that adds decorations (bullets or any kind of
// symbol) in a gutter in front of document's lines. See the CodeMirror's
// documentation on GutterMarker for further details.
export function createGutter<I extends Dict>(
  deps: Dependencies<I>,
  className: string,
  line: (inputs: I, block: Range, view: EditorView) => GutterMarker | null
): Extension {
  const enables = mapDict(deps, getExtension);
  const extension = gutter({
    class: className,
    lineMarker: (view, block) => {
      return line(inputs(deps, view.state) as I, block, view);
    }
  });
  return enables.concat(extension);
}

// A Tooltip is an extension that adds decorations as a floating DOM element
// above or below some text. See the CodeMirror's documentation on Tooltip
// for further details.
export function createTooltip<I extends Dict>(
  deps: Dependencies<I>,
  fn: (input: I) => Tooltip | Tooltip[] | undefined,
): Extension {
  const { structure, extension } = createAspect(deps, fn);
  const show = showTooltip.computeN([structure], st => {
    const tip = st.facet(structure);
    if (tip === undefined) return [null];
    if ('length' in tip) return tip;
    return [tip];
  });
  return [extension, show];
}

// An Event Handler is an extention responsible of performing a computation each
// time a DOM event (like <mouseup> or <contextmenu>) happens.
export function createEventHandler<I extends Dict>(
  deps: Dependencies<I>,
  handlers: Handlers<I>,
): Extension {
  const enables = mapDict(deps, getExtension);
  const domEventHandlers = Object.fromEntries(Object.keys(handlers).map((k) => {
    const h = handlers[k] as Handler<I, typeof k>;
    const fn = (e: typeof k, v: EditorView): void =>
      h(inputs(deps, v.state) as I, v, e);
    return [k, fn];
  }));
  return enables.concat(EditorView.domEventHandlers(domEventHandlers));
}



// -----------------------------------------------------------------------------
//  Code highlighting and parsing
// -----------------------------------------------------------------------------

// Plugin specifying how to highlight the code. The theme is handled by the CSS.
const Highlight = Language.syntaxHighlighting(Language.HighlightStyle.define([
  { tag: tags.comment, class: 'cm-comment' },
  { tag: tags.typeName, class: 'cm-type' },
  { tag: tags.number, class: 'cm-number' },
  { tag: tags.controlKeyword, class: 'cm-keyword' },
  { tag: tags.definition(tags.variableName) , class: 'cm-def' },
]));

// A language provider based on the [Lezer C++ parser], extended with
// highlighting and folding information. Only comments can be folded.
// (Source: https://github.com/lezer-parser/cpp)
const comment = (t: SyntaxNode): Range => ({ from: t.from + 2, to: t.to - 2});
const folder = Language.foldNodeProp.add({ BlockComment: comment });
const stringPrefixes = [ "L", "u", "U", "u8", "LR", "UR", "uR", "u8R", "R" ];
const cppLanguage = Language.LRLanguage.define({
  parser: parser.configure({ props: [ folder ] }),
  languageData: {
    commentTokens: { line: "//", block: { open: "/*", close: "*/" } },
    indentOnInput: /^\s*(?:case |default:|\{|\})$/,
    closeBrackets: { stringPrefixes },
  }
});

// This extension enables all the language highlighting features.
export const LanguageHighlighter: Extension =
  [Highlight, new Language.LanguageSupport(cppLanguage)];

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Standard extensions builders
// -----------------------------------------------------------------------------

export type ToString<A> = (text: A) => string;
export function createTextField<A>(init: A, toString: ToString<A>): Field<A> {
  const { get, set, structure } = createField<A>(init);
  const useSet: Set<A> = (view, text) => {
    set(view, text);
    React.useEffect(() => {
      const selection = { anchor: 0 };
      const length = view?.state.doc.length;
      const changes = { from: 0, to: length, insert: toString(text) };
      view?.dispatch({ changes, selection });
    }, [view, text]);
  };
  return { init, get, set: useSet, structure };
}

export const LineNumbers = createLineNumbers();
function createLineNumbers(): Extension {
  return lineNumbers({
    formatNumber: (lineNo, state) => {
      if (state.doc.length === 0) return '';
      return lineNo.toString();
    }
  });
}

export const FoldGutter = createFoldGutter();
function createFoldGutter(): Extension {
  return Language.foldGutter();
}

export function foldAll(view: EditorView | null): void {
  if (view !== null) Language.foldAll(view);
}

export function unfoldAll(view: EditorView | null): void {
  if (view !== null) Language.unfoldAll(view);
}

export function createLineField(): Field<number> {
  const { get, set, structure } = createField(0);
  const useSet: Set<number> = (view, lineNum) => {
    set(view, lineNum);
    React.useEffect(() => {
      if ((view?.state.doc.lines ?? 0) < lineNum + 1) return;
      const { from } = view?.state.doc.line(lineNum + 1) ?? { from: 0 };
      view?.dispatch({ selection: { anchor: from }, scrollIntoView: true });
    }, [view, lineNum]);
  };
  return { init: 0, get, set: useSet, structure };
}



// -----------------------------------------------------------------------------
//  Editor component
// -----------------------------------------------------------------------------

export interface Editor { view: EditorView | null; component: JSX.Element }

export function Editor(extensions: Extension[]): Editor {
  const parent = React.useRef(null);
  const editor = React.useRef<EditorView | null>(null);
  const component = <div className='cm-global-box' ref={parent} />;
  React.useEffect(() => {
    if (!parent.current) return;
    const state = EditorState.create({ extensions });
    editor.current = new EditorView({ state, parent: parent.current });
  }, [parent, extensions]);
  return { view: editor.current, component };
}

// -----------------------------------------------------------------------------
