import React from 'react';
import Lodash from 'lodash';
import { EditorState, StateField, Facet, Extension } from '@codemirror/state';
import { Annotation, Transaction, RangeSet } from '@codemirror/state';
import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { Decoration, DecorationSet } from '@codemirror/view';
import { DOMEventMap as EventMap } from '@codemirror/view';
import { GutterMarker, gutter } from '@codemirror/view';
import { showTooltip, Tooltip } from '@codemirror/view';

import { parser } from '@lezer/cpp';
import { tags } from '@lezer/highlight';
import { SyntaxNode } from '@lezer/common';
import { foldGutter, foldNodeProp } from '@codemirror/language';
import { LRLanguage, LanguageSupport } from "@codemirror/language";
import { syntaxHighlighting, HighlightStyle } from '@codemirror/language';

import * as Dome from 'dome';
import * as Utils from 'dome/data/arrays';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import { key } from 'dome/data/json';
import * as Ast from 'frama-c/kernel/api/ast';
import { text } from 'frama-c/kernel/api/data';
import * as Eva from 'frama-c/plugins/eva/api/general';
import * as Properties from 'frama-c/kernel/api/properties';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';

import { registerSandbox } from 'ivette';

import './dark-code.css';



// -----------------------------------------------------------------------------
//  CodeMirror state's extensions types definitions
// -----------------------------------------------------------------------------

// Helper types definitions.
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



// -----------------------------------------------------------------------------
//  CodeMirror state's extensions dependencies
// -----------------------------------------------------------------------------

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
//  Utilitary types and functions
// -----------------------------------------------------------------------------

// An alias type for functions and locations.
type Fct = string | undefined;
type Marker = Ast.marker | undefined;

// A Caller is just a pair of the caller's key and the statement's key where the
// call occurs.
type Caller = { fct: key<'#fct'>, marker: key<'#stmt'> };

// A range is just a pair of position in the code.
interface Range { from: number, to: number }

// Type checking that an input is defined.
function isDef<A>(a: A | undefined): a is A { return a !== undefined; }

// Map a function over a list, removing all inputs that returned undefined.
function mapFilter<A, B>(xs: A[], fn: (x: A) => B | undefined): B[] {
  return xs.map(fn).filter(isDef);
}



// -----------------------------------------------------------------------------
//  Tree datatype definition and utiliary functions
// -----------------------------------------------------------------------------

// The code is given by the server has a tree but implemented with arrays and
// without information on the ranges of each element. It will be converted in a
// good old tree that carry those information.
interface Leaf extends Range { text: string }
interface Node extends Range { id: string, children: Tree[] }
type Tree = Leaf | Node;

// Utility functions on trees.
function isLeaf (t: Tree): t is Leaf { return 'text' in t; }
function isNode (t: Tree): t is Node { return 'id' in t && 'children' in t; }
const empty: Tree = { text: '', from: 0, to: 0 };

// Convert an Ivette text (i.e a function's code) into a Tree, adding range
// information to each construction.
function textToTree(t: text): Tree | undefined {
  function aux(t: text, from: number): [Tree | undefined, number] {
    if (t === null) return [undefined, from];
    if (typeof t === 'string') {
      const to = from + t.length;
      return [{ text: t, from, to }, to];
    }
    if (t.length < 2 || typeof t[0] !== 'string') return [undefined, from];
    const children: Tree[] = []; let acc = from;
    for (const child of t.slice(1)) {
      const [node, to] = aux(child, acc);
      if (node) children.push(node);
      acc = to;
    }
    return [{ id: t[0], from, to: acc, children }, acc];
  }
  const [res] = aux(t, 0);
  return res;
}

// Convert an Ivette text into a string to be displayed.
function textToString(text: text): string {
  if (Array.isArray(text)) return text.slice(1).map(textToString).join('');
  else if (typeof text === 'string') return text;
  else return '';
}

// Computes, for each markers of a tree, its range. Returns the map containing
// all those bindings.
function markersRangesOfTree(tree: Tree): Map<string, Range>{
  const ranges: Map<string, Range> = new Map();
  const toRanges = (tree: Tree): void => {
    if (!isNode(tree)) return;
    ranges.set(tree.id, tree);
    for (const child of tree.children) toRanges(child);
  };
  toRanges(tree);
  return ranges;
}

// Find the closest covering tagged node of a given position. Returns
// undefined if there is not relevant covering node.
function coveringNode(tree: Tree, pos: number): Node | undefined {
  if (isLeaf(tree)) return undefined;
  if (pos < tree.from || pos > tree.to) return undefined;
  const child = Utils.first(tree.children, (c) => coveringNode(c, pos));
  if (child && isNode(child)) return child;
  if (tree.from <= pos && pos < tree.to) return tree;
  return undefined;
}



// -----------------------------------------------------------------------------
//  Function code representation
// -----------------------------------------------------------------------------

// This field contains the current function's code as represented by Ivette.
// Its set function takes care to update the CodeMirror displayed document.
const Text = createTextField();
function createTextField(): Field<text> {
  const { get, set, structure } = createField<text>(null);
  const useSet: Set<text> = (view, text) => {
    set(view, text);
    React.useEffect(() => {
      const selection = { anchor: 0 };
      const length = view?.state.doc.length;
      const changes = { from: 0, to: length, insert: textToString(text) };
      view?.dispatch({ changes, selection });
    }, [view, text]);
  };
  return { init: null, get, set: useSet, structure };
}

// This aspect computes the tree representing the currently displayed function's
// code, represented by the <Text> field.
const Tree = createAspect({ t: Text }, ({ t }) => textToTree(t) ?? empty);

// This aspect computes the markers ranges of the currently displayed function's
// tree, represented by the <Tree> aspect.
const Ranges = createAspect({ t: Tree }, ({ t }) => markersRangesOfTree(t));



// -----------------------------------------------------------------------------
//  Selected marker representation
// -----------------------------------------------------------------------------

// This field contains the currently selected function.
const Fct = createField<Fct>(undefined);

// This field contains the currently selected marker.
const Marker = createField<Marker>(undefined);

// The Ivette selection must be updated by CodeMirror plugins. This input
// add the callback in the CodeMirror internal state.
type UpdateSelection = (a: States.SelectionActions) => void;
const UpdateSelection = createField<UpdateSelection>(() => { return; });

// The marker field is considered as the ground truth on what is selected in the
// CodeMirror document. To do so, we catch the mouseup event (so when the user
// select a new part of the document) and update the Ivette selection
// accordingly. This will update the Marker field during the next Editor
// component's render and thus update everything else.
const MarkerUpdater = createMarkerUpdater();
function createMarkerUpdater(): Extension {
  const deps = { fct: Fct, tree: Tree, update: UpdateSelection };
  return createEventHandler(deps, {
    mouseup: ({ fct, tree, update }, view) => {
      const main = view.state.selection.main;
      const id = coveringNode(tree, main.from)?.id;
      update({ location: { fct, marker: Ast.jMarker(id) } });
    }
  });
}



// -----------------------------------------------------------------------------
//  Hovered marker representation
// -----------------------------------------------------------------------------

// This field contains the currently hovered marker.
const Hovered = createField<Marker>(undefined);

// The Ivette hovered element must be updated by CodeMirror plugins. This
// field add the callback in the CodeMirror internal state.
type UpdateHovered = (h: States.Hovered) => void;
const UpdateHovered = createField<UpdateHovered>(() => { return ; });

// The Hovered field is updated each time the mouse moves through the CodeMirror
// document. The handlers updates the Ivette hovered information, which is then
// reflected on the Hovered field by the Editor component itself.
const HoveredUpdater = createHoveredUpdater();
function createHoveredUpdater(): Extension {
  const deps = { fct: Fct, tree: Tree, update: UpdateHovered };
  return createEventHandler(deps, {
    mousemove: (inputs, view, event) => {
      const { fct, tree, update: updateHovered } = inputs;
      const coords = { x: event.clientX, y: event.clientY };
      const pos = view.posAtCoords(coords); if (!pos) return;
      const hov = coveringNode(tree, pos); if (!hov) return;
      const from = view.coordsAtPos(hov.from); if (!from) return;
      const to = view.coordsAtPos(hov.to); if (!to) return;
      const left = Math.min(from.left, to.left);
      const right = Math.max(from.left, to.left);
      const top = Math.min(from.top, to.top);
      const bottom = Math.max(from.bottom, to.bottom);
      const horizontallyOk = left <= coords.x && coords.x <= right;
      const verticallyOk = top <= coords.y && coords.y <= bottom;
      if (!horizontallyOk || !verticallyOk) return;
      const marker = Ast.jMarker(hov?.id);
      updateHovered(marker ? { fct, marker } : undefined);
    }
  });
}



// -----------------------------------------------------------------------------
//  Plugin decorating hovered and selected elements
// -----------------------------------------------------------------------------

const CodeDecorator = createCodeDecorator();
function createCodeDecorator(): Extension {
  const hoveredClass = Decoration.mark({ class: 'cm-hovered-code' });
  const selectedClass = Decoration.mark({ class: 'cm-selected-code' });
  const deps = { ranges: Ranges, marker: Marker, hovered: Hovered };
  return createDecorator(deps, ({ ranges, marker: m, hovered: h }) => {
    const selected = m && ranges.get(m);
    const hovered = h && ranges.get(h);
    const range = selected && selectedClass.range(selected.from, selected.to);
    const add = hovered && [ hoveredClass.range(hovered.from, hovered.to) ];
    const set = range ? RangeSet.of(range) : RangeSet.empty;
    return set.update({ add, sort: true });
  });
}



// -----------------------------------------------------------------------------
//  Dead code decorations plugin
// -----------------------------------------------------------------------------

// This field contains the dead code information as inferred by Eva.
const Dead = createField<Eva.deadCode>({ unreachable: [], nonTerminating: [] });

const DeadCodeDecorator = createDeadCodeDecorator();
function createDeadCodeDecorator(): Extension {
  const uClass = Decoration.mark({ class: 'cm-dead-code' });
  const tClass = Decoration.mark({ class: 'cm-non-term-code' });
  const deps = { dead: Dead, ranges: Ranges };
  return createDecorator(deps, ({ dead, ranges }) => {
    const range = (marker: string): Range | undefined => ranges.get(marker);
    const unreachableRanges = mapFilter(dead.unreachable, range);
    const unreachable = unreachableRanges.map(r => uClass.range(r.from, r.to));
    const nonTermRanges = mapFilter(dead.nonTerminating, range);
    const nonTerm = nonTermRanges.map(r => tClass.range(r.from, r.to));
    return RangeSet.of(unreachable.concat(nonTerm), true);
  });
}



// -----------------------------------------------------------------------------
//  Property bullets extension
// -----------------------------------------------------------------------------

// This field contains information on properties' tags.
type Tags = Map<string, States.Tag>;
const Tags = createField<Tags>(new Map());

// The component needs information on markers' status data.
const PropertiesStatuses = createField<Properties.statusData[]>([]);

// This aspect filters all properties that does not have a valid range, and
// stores the remaining properties with their ranges.
const PropertiesRanges = createPropertiesRange();
interface PropertyRange extends Properties.statusData { range: Range }
function createPropertiesRange(): Aspect<PropertyRange[]> {
  const deps = { props: PropertiesStatuses, ranges: Ranges };
  return createAspect(deps, ({ props, ranges }) => mapFilter(props, (p) => {
    const range = ranges.get(p.key);
    return range && { ...p, range };
  }));
}

// This aspect computes the tag associated to each property.
const PropertiesTags = createPropertiesTags();
function createPropertiesTags(): Aspect<Map<string, States.Tag>> {
  const deps = { statuses: PropertiesStatuses, tags: Tags };
  return createAspect(deps, ({ statuses, tags }) => {
    const res = new Map<string, States.Tag>();
    for (const p of statuses) {
      if (!p.status) continue;
      const tag = tags.get(p.status);
      if (tag) res.set(p.key, tag);
    }
    return res;
  });
}

// Bullet colors.
function getBulletColor(status: States.Tag): string {
  switch (status.name) {
    case 'unknown': return '#FF8300';
    case 'invalid':
    case 'invalid_under_hyp': return '#FF0000';
    case 'valid':
    case 'valid_under_hyp': return '#00B900';
    case 'considered_valid': return '#73bbbb';
    case 'invalid_but_dead':
    case 'valid_but_dead':
    case 'unknown_but_dead': return '#000000';
    case 'never_tried': return '#FFFFFF';
    case 'inconsistent': return '#FF00FF';
    default: return '#FF8300';
  }
}

// Property bullet gutter marker.
class PropertyBullet extends GutterMarker {
  readonly bullet: HTMLDivElement;
  toDOM(): HTMLDivElement { return this.bullet; }
  constructor(status?: States.Tag) {
    super();
    this.bullet = document.createElement('div');
    this.bullet.innerHTML = '◉';
    if (status) {
      this.bullet.style.color = getBulletColor(status);
      this.bullet.style.textAlign = 'center';
      if (status.descr) this.bullet.title = status.descr;
    }
  }
}

const PropertiesGutter = createPropertiesGutter();
function createPropertiesGutter(): Extension {
  const deps = { ranges: PropertiesRanges, propTags: PropertiesTags };
  return createGutter(deps, 'cm-property-gutter', (inputs, block, view) => {
    const { ranges, propTags } = inputs;
    const line = view.state.doc.lineAt(block.from);
    const start = line.from; const end = line.to;
    const inLine = (r: Range): boolean => start <= r.from && r.to <= end;
    function isHeader(r: Range): boolean {
      if (!line.text.includes('requires')) return false;
      const next = view.state.doc.line(line.number + 1);
      return r.from <= next.from && next.to <= r.to;
    }
    const prop = ranges.find((r) => inLine(r.range) || isHeader(r.range));
    if (!prop) return null;
    const statusTag = propTags.get(prop.key);
    return statusTag ? new PropertyBullet(statusTag) : null;
  });
}



// -----------------------------------------------------------------------------
//  Studia access
// -----------------------------------------------------------------------------

type access = 'Reads' | 'Writes';

interface StudiaProps {
  marker: string,
  info: Ast.markerInfoData,
  kind: access,
}

interface StudiaInfos {
  name: string,
  title: string,
  locations: { fct: key<'#fct'>, marker: Ast.marker }[],
  index: number,
}

async function studia(props: StudiaProps): Promise<StudiaInfos> {
  const { marker, info, kind } = props;
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker);
  const locations = data.direct.map(([f, m]) => ({ fct: f, marker: m }));
  const lval = info.name;
  if (locations.length > 0) {
    const name = `${kind} of ${lval}`;
    const acc = (kind === 'Reads') ? 'accessing' : 'modifying';
    const title =
      `List of statements ${acc} the memory location pointed by ${lval}.`;
    return { name, title, locations, index: 0 };
  }
  const name = `No ${kind.toLowerCase()} of ${lval}`;
  return { name, title: '', locations: [], index: 0 };
}



// -----------------------------------------------------------------------------
//  Context menu
// -----------------------------------------------------------------------------

// This field contains all the current function's callers, as inferred by Eva.
const Callers = createField<Caller[]>([]);

// This field contains information on markers.
type GetMarkerData = (key: string) => Ast.markerInfoData | undefined;
const GetMarkerData = createField<GetMarkerData>(() => undefined);

const ContextMenuHandler = createContextMenuHandler();
function createContextMenuHandler(): Extension {
  const data = { tree: Tree, locations: Callers };
  const deps = { ...data, update: UpdateSelection, getData: GetMarkerData };
  return createEventHandler(deps, {
    contextmenu: (inputs, view, event) => {
      const { tree, locations, update, getData } = inputs;
      const coords = { x: event.clientX, y: event.clientY };
      const position = view.posAtCoords(coords); if (!position) return;
      const node = coveringNode(tree, position);
      if (!node || !node.id) return;
      const items: Dome.PopupMenuItem[] = [];
      const info = getData(node.id);
      if (info?.var === 'function') {
        if (info.kind === 'declaration') {
          const callers = Lodash.groupBy(locations, e => e.fct);
          Lodash.forEach(callers, (e) => {
            const callerName = e[0].fct;
            const callSites = e.length > 1 ? `(${e.length} call sites)` : '';
            items.push({
              label: `Go to caller ${callerName} ` + callSites,
              onClick: () => update({
                name: `Call sites of function ${info.name}`,
                locations: locations,
                index: locations.findIndex(l => l.fct === callerName)
              })
            });
          });
        } else {
          const location = { fct: info.name };
          const onClick = (): void => update({ location });
          const label = `Go to definition of ${info.name}`;
          items.push({ label, onClick });
        }
      }
      const enabled = info?.kind === 'lvalue' || info?.var === 'variable';
      const onClick = (kind: access): void => {
        if (info && node.id)
          studia({ marker: node.id, info, kind }).then(update);
      };
      const reads = 'Studia: select reads';
      const writes = 'Studia: select writes';
      items.push({ label: reads, enabled, onClick: () => onClick('Reads') });
      items.push({ label: writes, enabled, onClick: () => onClick('Writes') });
      if (items.length > 0) Dome.popupMenu(items);
      return;
    }
  });
}



// -----------------------------------------------------------------------------
//  Tainted lvalues
// -----------------------------------------------------------------------------

type Taints = Eva.LvalueTaints;
const TaintedLvalues = createField<Taints[] | undefined>(undefined);

function textOfTaint(taint: Eva.taintStatus): string {
  switch (taint) {
    case 'not_computed': return 'The taint has not been computed';
    case 'error': return 'There was an error during the taint computation';
    case 'not_applicable': return 'No taint for this lvalue';
    case 'direct_taint': return 'This lvalue can be affected by an attacker';
    case 'indirect_taint':
      return 'This lvalue depends on path conditions that can \
      be affected by an attacker';
    case 'not_tainted': return 'This lvalue is safe';
  }
  return '';
}

const TaintedLvaluesDecorator = createTaintedLvaluesDecorator();
function createTaintedLvaluesDecorator(): Extension {
  const mark = Decoration.mark({ class: 'cm-tainted' });
  const deps = { ranges: Ranges, tainted: TaintedLvalues };
  return createDecorator(deps, ({ ranges, tainted = [] }) => {
    const find = (t: Taints): Range | undefined => ranges.get(t.lval);
    const marks = mapFilter(tainted, find).map(r => mark.range(r.from, r.to));
    return RangeSet.of(marks, true);
  });
}

const TaintTooltip = createTaintTooltip();
function createTaintTooltip(): Extension {
  const deps = { hovered: Hovered, ranges: Ranges, tainted: TaintedLvalues };
  return createTooltip(deps, ({ hovered, ranges, tainted }) => {
    const hoveredTaint = tainted?.find(t => t.lval === hovered);
    const hoveredNode = hovered && ranges.get(hovered);
    if (!hoveredTaint || !hoveredNode) return undefined;
    return {
      pos: hoveredNode.from,
      above: true,
      strictSide: true,
      arrow: true,
      create: () => {
        const dom = document.createElement('div');
        dom.className = 'cm-tainted-tooltip';
        dom.textContent = textOfTaint(hoveredTaint.taint);
        return { dom };
      }
    };
  });
}



// -----------------------------------------------------------------------------
//  Code highlighting and parsing
// -----------------------------------------------------------------------------

// Plugin specifying how to highlight the code. The theme is handled by the CSS.
const Highlight = syntaxHighlighting(HighlightStyle.define([
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
const folder = foldNodeProp.add({ BlockComment: comment });
const stringPrefixes = [ "L", "u", "U", "u8", "LR", "UR", "uR", "u8R", "R" ];
const cppLanguage = LRLanguage.define({
  parser: parser.configure({ props: [ folder ] }),
  languageData: {
    commentTokens: { line: "//", block: { open: "/*", close: "*/" } },
    indentOnInput: /^\s*(?:case |default:|\{|\})$/,
    closeBrackets: { stringPrefixes },
  }
});



// -----------------------------------------------------------------------------
//  Server requests
// -----------------------------------------------------------------------------

// Server request handler returning the given function's text.
function useFctText(fct: Fct): text {
  const req = React.useMemo(() => Server.send(Ast.printFunction, fct), [fct]);
  const { result } = Dome.usePromise(req);
  return result ?? null;
}

// Server request handler returning the given function's dead code information.
function useFctDead(fct: Fct): Eva.deadCode {
  const req = React.useMemo(() => Server.send(Eva.getDeadCode, fct), [fct]);
  const { result } = Dome.usePromise(req);
  return result ?? { unreachable: [], nonTerminating: [] };
}

// Server request handler returning the given function's callers.
function useFctCallers(fct: Fct): Caller[] {
  const req = React.useMemo(() => Server.send(Eva.getCallers, fct), [fct]);
  const { result = [] } = Dome.usePromise(req);
  return result.map(([fct, marker]) => ({ fct, marker }));
}

// Server request handler returning the tainted lvalues.
function useFctTaints(fct: Fct): Eva.LvalueTaints[] {
  const req = React.useMemo(() => Server.send(Eva.taintedLvalues, fct), [fct]);
  const { result = [] } = Dome.usePromise(req);
  return result;
}



// -----------------------------------------------------------------------------
//  AST View component
// -----------------------------------------------------------------------------

// Necessary extensions for our needs.
const baseExtensions: Extension[] = [
  MarkerUpdater,
  HoveredUpdater,
  CodeDecorator,
  DeadCodeDecorator,
  ContextMenuHandler,
  PropertiesGutter,
  foldGutter(),
  TaintedLvaluesDecorator,
  TaintTooltip,
  Highlight, new LanguageSupport(cppLanguage),
];

// The component in itself.
function Editor(): JSX.Element {

  // Creating the codemirror vue and binding it to the editor div.
  const parent = React.useRef(null);
  const editor = React.useRef<EditorView | null>(null);
  React.useEffect(() => {
    if (!parent.current) return;
    const state = EditorState.create({ extensions: baseExtensions });
    editor.current = new EditorView({ state, parent: parent.current });
  }, [parent]);

  // Updating CodeMirror when the selection or its callback are changed.
  const [selection, updateSelection] = States.useSelection();
  UpdateSelection.set(editor.current, updateSelection);

  // Updating CodeMirror when the <updateHovered> callback is changed.
  const [hovered, updateHovered] = States.useHovered();
  UpdateHovered.set(editor.current, updateHovered);

  // Updating CodeMirror when the <properties> synchronized array is changed.
  const properties = States.useSyncArray(Properties.status).getArray();
  PropertiesStatuses.set(editor.current, properties);

  // Updating CodeMirror when the <propStatusTags> map is changed.
  const tags = States.useTags(Properties.propStatusTags);
  Tags.set(editor.current, tags);

  // Updating CodeMirror when the <markersInfo> synchronized array is changed.
  const info = States.useSyncArray(Ast.markerInfo);
  const getMarkerData = React.useCallback((key) => info.getData(key), [info]);
  GetMarkerData.set(editor.current, getMarkerData);

  // Retrieving data on currently selected function and updating CodeMirror when
  // they have changed.
  const fct = selection?.current?.fct;
  const marker = selection?.current?.marker;
  Text.set(editor.current, useFctText(fct));
  Fct.set(editor.current, fct);
  Marker.set(editor.current, marker);
  Hovered.set(editor.current, hovered?.marker);
  Dead.set(editor.current, useFctDead(fct));
  Callers.set(editor.current, useFctCallers(fct));
  TaintedLvalues.set(editor.current, useFctTaints(fct));

  return <div className='cm-global-box' ref={parent} />;
}



registerSandbox({
  id: 'codemirror6',
  label: 'CodeMirror 6',
  children: <Editor />,
});
