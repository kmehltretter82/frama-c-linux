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
import { Change, diffLines } from 'diff';

/* -------------------------------------------------------------------------- */
/* --- Basic Definitions                                                  --- */
/* -------------------------------------------------------------------------- */

export interface Offset { offset: number; }
export interface Range extends Offset { length: number }
export interface Position extends Offset { line: number }
export interface Selection extends Range { fromLine: number, toLine: number }

export const emptySelection : Range & Selection =
  { offset: 0, length: 0, fromLine: 1, toLine: 1 };

export function byDepth(a : Range, b : Range): number
{
  return (a.length - b.length) || (b.offset - a.offset);
}

export function byOffset(a : Offset, b : Offset): number
{
  return (a.offset - b.offset);
}

type View = CM.EditorView | null;

/* -------------------------------------------------------------------------- */
/* --- Text View Updates                                                  --- */
/* -------------------------------------------------------------------------- */

function appendContents(view: CM.EditorView, text: string): void {
  const length = view.state.doc.length;
  view.dispatch({ changes: { from: length, insert: text } });
}

function dispatchContents(view: CM.EditorView, text: string | CS.Text): void {
  const length = view.state.doc.length;
  view.dispatch({ changes: { from: 0, to: length, insert: text } });
}

class DiffBuffer {
  private readonly changes : CS.ChangeSpec[] = [];
  private offset = 0;
  private added = '';
  private removed = 0;

  constructor() { this.add = this.add.bind(this); }

  private commit(forward=0): void {
    const { changes, offset, added, removed } = this;
    if (added || removed) {
      const nextOffset = offset + removed;
      changes.push({ from: offset, to: nextOffset, insert: added });
      this.offset = nextOffset + forward;
      this.added = '';
      this.removed = 0;
    } else
      if (forward) this.offset += forward;
  }

  add(c : Change): void {
    if (c.added) this.added += c.value;
    if (c.removed) this.removed += c.value.length;
    if (!c.added && !c.removed) this.commit(c.value.length);
  }

  flush(): CS.ChangeSpec {
    this.commit();
    return this.changes;
  }

}

function updateContents(view: CM.EditorView, newText: string): void {
  const buffer = new DiffBuffer();
  diffLines(view.state.doc.toString(), newText).forEach(buffer.add);
  view.dispatch({ changes: buffer.flush() });
}

/* -------------------------------------------------------------------------- */
/* --- Text Proxy                                                         --- */
/* -------------------------------------------------------------------------- */

/** Text proxy to a RichText component.

   This class can be used as a proxy to the content of a {RichText} component,
   provided such a component has been associated with the proxy.

   Methods of the class are no-ops when there is no associated view, and at most
   one component shall be associated with a given Text buffer at the same time.

   <b>Warning:</n> do not access proxy's methods during React component
   rendering since they would not be synchronized with further changes from
   document or editor view. Rather, those methods shall be invoked from
   React and event callbacks.

   All methods are bound to `this`.  */
export class TextProxy {

  // --- Private part

  protected proxy : View = null;

  constructor() {
    this.range = this.range.bind(this);
    this.clear = this.clear.bind(this);
    this.append = this.append.bind(this);
    this.toString = this.toString.bind(this);
    this.setContents = this.setContents.bind(this);
    this.connect = this.connect.bind(this);
  }

  /** @ignore */
  connect(newView: View): void { this.proxy = newView; }

  // --- Public part

  /** Full document range. Remark: empty documents still have 1 (empty) line. */
  range(): Selection {
    const view = this.proxy;
    if (view === null) return emptySelection;
    const doc = view.state.doc;
    return { offset: 0, length: doc.length, fromLine: 1, toLine: doc.lines };
  }

  /** Remove all text from document. */
  clear(): void {
    const view = this.proxy;
    if (view) dispatchContents(view, CS.Text.empty);
  }

  /** Full document contents. */
  toString(): string {
    const view = this.proxy;
    return view ? view.state.doc.toString() : '';
  }

  /** Appends to end of document. */
  append(data: string): void {
    const view = this.proxy;
    if (view) appendContents(view, data);
  }

  /** Appends to end of document. */
  setContents(data: string): void {
    const view = this.proxy;
    if (view) dispatchContents(view, data);
  }

  /** Uses diff changes instead of replacing the entire view's contents. */
  updateContents(data: string): void {
    const view = this.proxy;
    if (view) updateContents(view, data);
  }

}

/* -------------------------------------------------------------------------- */
/* --- Text Buffer                                                        --- */
/* -------------------------------------------------------------------------- */

const NewLine = /(\r\n|\r|\n)/;
function textOf(text: string): CS.Text {
  return CS.Text.of(text.split(NewLine));
}

/** Text buffer extends a text proxy by making the contents persistent.

   Contents is kept in sync with the associated view, and is still maintained or
   updated when the view is unmounted.

   All methods are bound to `this`. */
export class TextBuffer extends TextProxy {

  // --- Private part (we avoid unecessary conversions from/to text)
  // --- Invariant: only one of proxy, text or contents holds data

  private text = CS.Text.empty;
  private contents : string | undefined = undefined;
  private toText(): CS.Text {
    // --- requires this.proxy is null
    const contents = this.contents;
    if (contents===undefined) return this.text;
    const text = textOf(contents);
    this.text = text;
    this.contents = undefined;
    // --- invariant established
    return text;
  }

  /** @ignore */
  connect(newView: View): void {
    const oldView = this.proxy;
    if (oldView) {
      this.proxy = null;
      this.text = oldView.state.doc;
      // invariant preserved
    }
    if (newView) {
      const newData = this.contents ?? this.text;
      this.proxy = newView;
      this.text = CS.Text.empty;
      this.contents = undefined;
      // invariant established
      dispatchContents(newView, newData);
    }
  }

  // --- Public part

  range(): Selection {
    if (this.proxy) return super.range();
    const doc = this.toText();
    return { offset: 0, length: doc.length, fromLine: 1, toLine: doc.lines };
  }

  clear(): void {
    const view = this.proxy;
    if (view) dispatchContents(view, CS.Text.empty);
    else {
      this.text = CS.Text.empty;
      this.contents = undefined;
      // invariant established
    }
  }

  toString(): string {
    const view = this.proxy;
    if (view) return view.state.doc.toString();
    return this.contents ?? this.text.toString();
  }

  append(data: string): void {
    const view = this.proxy;
    if (view) { appendContents(view, data); }
    else {
      this.text = this.toText().append(textOf(data));
      this.contents = undefined;
      // invariant established
    }
  }

  setContents(data: string): void {
    const view = this.proxy;
    if (view) dispatchContents(view, data);
    else {
      this.contents = data;
      this.text = CS.Text.empty;
      // invariant established
    }
  }

  /** Uses diff changes instead of replacing the entire view's contents. */
  updateContents(data: string): void {
    const view = this.proxy;
    if (view) updateContents(view, data);
    else {
      this.contents = data;
      this.text = CS.Text.empty;
      // invariant established
    }
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

class Option extends Extension {

  private readonly spec: CS.Extension;
  private readonly comp = new CS.Compartment();

  constructor(extension: CS.Extension, active=true) {
    super();
    this.spec = extension;
    this.pack(this.comp.of(active ? extension : []));
  }

  dispatch(view: View, active?: boolean): void {
    if (view !== null && active !== undefined) {
      const effects = this.comp.reconfigure(active ? this.spec : []);
      view.dispatch({ effects });
    }
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
/* --- Selection Builder                                                  --- */
/* -------------------------------------------------------------------------- */

type cmrange = { from: number, to: number };

function selection(doc: CS.Text, range: cmrange) : Selection {
  const { from: offset, to: endOffset } = range;
  const fromLine = doc.lineAt(offset).number;
  const toLine = doc.lineAt(endOffset).number;
  return { offset, length: endOffset - offset, fromLine, toLine };
}

/* -------------------------------------------------------------------------- */
/* --- Selection Change Listener                                          --- */
/* -------------------------------------------------------------------------- */

export type SelectionCallback = (S: Selection) => void;

const OnSelect = new Field<SelectionCallback|null>(null);

OnSelect.pack(
  CM.EditorView.updateListener.computeN(
    [OnSelect.field],
    (state) => {
      const callback = state.field(OnSelect.field);
      if (callback !== null)
        return [
          (updates: CM.ViewUpdate) => {
            const oldSel = updates.startState.selection.main;
            const newSel = updates.state.selection.main;
            const doc = updates.state.doc;
            if (!newSel.eq(oldSel)) callback(selection(doc, newSel));
        }];
      return [];
    }
));

/* -------------------------------------------------------------------------- */
/* --- Viewport Change Listener                                           --- */
/* -------------------------------------------------------------------------- */

const Viewport = new Field<SelectionCallback|null>(null);

Viewport.pack(
  CM.EditorView.updateListener.computeN(
    [Viewport.field],
    (state) => {
      const callback = state.field(Viewport.field);
      if (callback !== null)
        return [
          (updates: CM.ViewUpdate) => {
            if (updates.viewportChanged) {
              const sel = updates.view.viewport;
              const doc = updates.state.doc;
              callback(selection(doc, sel));
            }
        }];
      return [];
    }
));

/* -------------------------------------------------------------------------- */
/* --- Decorations                                                        --- */
/* -------------------------------------------------------------------------- */

export interface MarkDecoration extends Range {

  /** The class of the decoration. */
  className?: string;

  /** The tooltip title of the decoration. */
  title?: string;

  /**
     Whether the decoration shall extend to characters inserted
     at start end end positions. Defaults to false.
   */
  inclusive?: boolean;
}

export interface LineDecoration {

  /** The line number to be decorated. */
  line: number;

  /** The class of the decoration. */
  className?: string;

  /** The tooltip title of the decoration. */
  title?: string;

}

export interface GutterDecoration extends LineDecoration {

  /** The gutter text mark (shall be few chatracters long). */
  gutter: string;

}

export type Decoration = MarkDecoration | LineDecoration | GutterDecoration;
export type Decorations = null | Decoration | readonly Decoration[];

/* -------------------------------------------------------------------------- */
/* --- Decoration Builder                                                 --- */
/* -------------------------------------------------------------------------- */

function isDecoration(d : Decorations) : d is Decoration
{
  return d !== null && !Array.isArray(d);
}

function isMarkDecoration(d : Decoration) : d is MarkDecoration
{
  // eslint-disable-next-line no-prototype-builtins
  return d.hasOwnProperty("offset") && d.hasOwnProperty("length");
}

function isLineDecoration(d : Decoration) : d is LineDecoration
{
  // eslint-disable-next-line no-prototype-builtins
  return d.hasOwnProperty("line") && !d.hasOwnProperty("gutter");
}

function isGutterDecoration(d : Decoration) : d is GutterDecoration
{
  // eslint-disable-next-line no-prototype-builtins
  return d.hasOwnProperty("line") && d.hasOwnProperty("gutter");
}

/* -------------------------------------------------------------------------- */
/* --- Gutter Builder                                                     --- */
/* -------------------------------------------------------------------------- */

class GutterMark extends CM.GutterMarker {
  private spec: GutterDecoration;

  constructor(spec: GutterDecoration) {
    super();
    this.spec = spec;
  }

  toDOM(): Node {
    const {  gutter, className, title } = this.spec;
    const textNode = document.createTextNode(gutter);
    if (!className && !title) return textNode;
    const span = document.createElement("div");
    span.appendChild(textNode);
    if (className) span.className = className;
    if (title) span.title = title;
    return span;
  }

}

const GutterMarks : Map<string, GutterMark> = new Map();

function gutterMark(spec: GutterDecoration) : CM.GutterMarker {
  const { gutter, className='', title='' } = spec;
  const key = `G${gutter}@C${className}@T${title}`;
  let marker = GutterMarks.get(key);
  if (!marker) {
    marker = new GutterMark(spec);
    GutterMarks.set(key, marker);
  }
  return marker;
}

/* -------------------------------------------------------------------------- */
/* --- Decorations Builder                                                --- */
/* -------------------------------------------------------------------------- */

interface RangeValue<A> extends Range { value: A }

function byRange<A>(a: RangeValue<A>, b: RangeValue<A>): number {
  return (a.offset - b.offset) || (a.length - b.length);
}

function toRangeSet<A extends CS.RangeValue>(
  ranges: RangeValue<A>[]
): CS.RangeSet<A> {
  const buffer = new CS.RangeSetBuilder<A>();
  ranges.sort(byRange).forEach((r) =>
    buffer.add(r.offset, r.offset + r.length, r.value)
  );
  return buffer.finish();
}

class DecorationsBuilder {

  private ranges : RangeValue<CM.Decoration>[] = [];
  private gutters : RangeValue<CM.GutterMarker>[] = [];
  protected readonly doc : CS.Text;

  constructor(doc: CS.Text) {
    this.doc = doc;
    this.addSpec = this.addSpec.bind(this);
  }

  addMark(spec: MarkDecoration): void {
    const { offset, length, inclusive, className, title } = spec;
    if (offset < 0) return;
    if (offset + length > this.doc.length) return;
    const attributes = title ? { title } : undefined;
    const value = CM.Decoration.mark({
      'class': className,
      attributes,
      inclusive,
    });
    this.ranges.push({ offset, length, value });
  }

  addLine(spec: LineDecoration): void {
    const { line, className, title } = spec;
    if (line < 1) return;
    if (line > this.doc.lines) return;
    const offset = this.doc.line(line).from;
    const attributes = title ? { title } : undefined;
    const value = CM.Decoration.line({
      'class': className,
      attributes,
    });
    this.ranges.push({ offset, length: 0, value });
  }

  addGutter(spec: GutterDecoration): void {
    const { line } = spec;
    if (line < 1) return;
    if (line > this.doc.lines) return;
    const offset = this.doc.line(line).from;
    const value = gutterMark(spec);
    this.gutters.push({ offset, length: 0, value });
  }

  addSpec(spec : Decorations): void {
    if (spec !== null) {
      if (isDecoration(spec)) {
        if (isMarkDecoration(spec)) this.addMark(spec);
        if (isLineDecoration(spec)) this.addLine(spec);
        if (isGutterDecoration(spec)) this.addGutter(spec);
      } else spec.forEach(this.addSpec);
    }
  }

  getRanges(): CS.RangeSet<CM.Decoration> {
    return toRangeSet(this.ranges);
  }

  getGutters(): CS.RangeSet<CM.GutterMarker> {
    return toRangeSet(this.gutters);
  }

}

/* -------------------------------------------------------------------------- */
/* --- Decorations                                                        --- */
/* -------------------------------------------------------------------------- */

interface Decorator {
  spec : Decorations;
  ranges : CM.DecorationSet;
  gutters : CS.RangeSet<CM.GutterMarker>;
}

function compareDecorations(a : Decorations, b : Decorations): boolean
{
  if (a === b) return true;
  if (!Array.isArray(a)) return false;
  if (!Array.isArray(b)) return false;
  const n = a.length;
  if (n !== b.length) return false;
  for (let k = 0; k < n; k++) if (a[k] !== b[k]) return false;
  return true;
}

const DecoratorSpec = CS.Annotation.define<Decorations>();

const DecoratorState = CS.StateField.define<Decorator>({

  create: () => ({
    spec: null,
    ranges: CS.RangeSet.empty,
    gutters: CS.RangeSet.empty,
  }),

  update(value: Decorator, tr: CS.Transaction) {
    const newSpec : Decorations = tr.annotation(DecoratorSpec) ?? null;
    if (newSpec !== null && !compareDecorations(newSpec, value.spec)) {
      const builder = new DecorationsBuilder(tr.newDoc);
      builder.addSpec(newSpec);
      return {
        spec: newSpec,
        ranges: builder.getRanges(),
        gutters: builder.getGutters(),
      };
    }
    if (tr.docChanged)
      return {
        spec: value.spec,
        ranges: value.ranges.map(tr.changes),
        gutters: value.gutters.map(tr.changes),
      };
    return value;
  },

});

function dispatchDecorations(view: View, spec: Decorations): void {
  view?.dispatch({ annotations: DecoratorSpec.of(spec) });
}

const Decorations: CS.Extension = [
  DecoratorState,
  CM.EditorView.decorations.from(DecoratorState, ({ ranges }) => ranges),
  CM.gutter({ markers: (view) => view.state.field(DecoratorState).gutters, }),
];

/* -------------------------------------------------------------------------- */
/* --- Line Numbers                                                       --- */
/* -------------------------------------------------------------------------- */

const LineNumbers = new Option(CM.lineNumbers());

/* -------------------------------------------------------------------------- */
/* --- Active Line                                                        --- */
/* -------------------------------------------------------------------------- */

const ActiveLine = new Option([
  CM.highlightActiveLine(),
  CM.highlightActiveLineGutter(),
]);

/* -------------------------------------------------------------------------- */
/* --- Editor View                                                        --- */
/* -------------------------------------------------------------------------- */

function createView(parent: Element): CM.EditorView {
  const extensions : CS.Extension[] = [
    LineNumbers,
    ActiveLine,
    ReadOnly,
    OnChange,
    OnSelect,
    Viewport,
    Decorations,
  ];
  const state = CS.EditorState.create({ extensions });
  return new CM.EditorView({ state, parent });
}

/* -------------------------------------------------------------------------- */
/* --- Rich Text Component                                                --- */
/* -------------------------------------------------------------------------- */

export interface TextViewProps {
  text?: TextProxy;
  readOnly?: boolean;
  onChange?: Callback;
  selection?: Range;
  onViewport?: SelectionCallback;
  onSelection?: SelectionCallback;
  decorations?: Decorations;
  lineNumbers?: boolean;
  showCurrentLine?: boolean;
  display?: boolean;
  visible?: boolean;
  className?: string;
  style?: CSSProperties;
}

export function TextView(props: TextViewProps) : JSX.Element {
  const [view, setView] = React.useState<View>(null);

  // --- Text Proxy
  const { text } = props;
  React.useEffect(() => {
    if (text) {
      text.connect(view);
      if (view) return () => text.connect(null);
    }
    return undefined;
  }, [text, view]);

  // ---- readOnly, onChange, onSelection, lineNumbers
  const {
    readOnly = false,
    onChange = null,
    onViewport: onReview = null,
    onSelection: onSelect = null,
    lineNumbers: lines,
    showCurrentLine: active,
  } = props;
  React.useEffect(() => ReadOnly.dispatch(view, readOnly), [view, readOnly]);
  React.useEffect(() => OnChange.dispatch(view, onChange), [view, onChange]);
  React.useEffect(() => OnSelect.dispatch(view, onSelect), [view, onSelect]);
  React.useEffect(() => Viewport.dispatch(view, onReview), [view, onReview]);
  React.useEffect(() => LineNumbers.dispatch(view, lines), [view, lines]);
  React.useEffect(() => ActiveLine.dispatch(view, active), [view, active]);

  // ---- Decorations
  const { decorations: decors = null } = props;
  React.useEffect(() => dispatchDecorations(view, decors), [view, decors]);

  // ---- Selection
  const { selection } = props;
  React.useEffect(() => {
    if (selection) {
      const anchor = selection.offset;
      const head = anchor + selection.length;
      view?.dispatch({ scrollIntoView: true, selection: { anchor, head } });
    }
  }, [view, selection]);

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
