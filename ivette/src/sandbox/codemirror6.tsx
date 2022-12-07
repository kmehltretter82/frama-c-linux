import React from 'react';
import Dictionary from 'lodash';
import { EditorState, StateField, Facet, Extension } from '@codemirror/state';
import { Annotation, Transaction, RangeSet } from '@codemirror/state';
import { Decoration, DecorationSet } from '@codemirror/view';
import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { DOMEventHandlers, GutterMarker, gutter } from '@codemirror/view';

import { tags } from '@lezer/highlight';
import { syntaxHighlighting, HighlightStyle } from '@codemirror/language';

import { parser } from '@lezer/cpp';
import { SyntaxNode } from '@lezer/common';
import { foldGutter, foldNodeProp } from '@codemirror/language';
import { LRLanguage, LanguageSupport } from "@codemirror/language";

import * as Dome from 'dome';
import * as Utils from 'dome/data/arrays';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import type { key } from 'dome/data/json';
import * as Ast from 'frama-c/kernel/api/ast';
import { text } from 'frama-c/kernel/api/data';
import * as Eva from 'frama-c/plugins/eva/api/general';
import * as Properties from 'frama-c/kernel/api/properties';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';

import { registerSandbox } from 'ivette';

import './dark-code.css';



// -----------------------------------------------------------------------------
//  Helper types definitions
// -----------------------------------------------------------------------------

export type Get<A> = (state: EditorState | undefined) => A;
export type Set<A> = (view: EditorView | null, value: A) => void;
export type Equal<A> = (left: A, right: A) => boolean;
export interface Data<A, S> { init: A, get: Get<A>, structure: S }



// -----------------------------------------------------------------------------
//  CodeMirror's Fields
// -----------------------------------------------------------------------------

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

// A Field is simply declared using an initial value. However, to be able to
// use it, you must add its extension (obtained through <field.extension>) to
// the CodeMirror initial configuration. If determining equality between
// values of the given type cannot be done using (===), an equality test can be
// provided through the optional parameters <equal>.
export function createField<A>(init: A, equal?: Equal<A>): Field<A> {
  const annot = Annotation.define<A>();
  const create = (): A => init;
  type Update<A> = (current: A, transaction: Transaction) => A;
  const update: Update<A> = (current, tr) => tr.annotation(annot) ?? current;
  const field = StateField.define<A>({ create, update, compare: equal });
  const get: Get<A> = (state) => state?.field(field) ?? init;
  const useSet: Set<A> = (v, a) =>
    React.useEffect(() => v?.dispatch({ annotations: annot.of(a) }), [v, a]);
  return { init, get, set: useSet, structure: field };
}



// -----------------------------------------------------------------------------
//  CodeMirror's Aspects
// -----------------------------------------------------------------------------

// An Aspect is a data associated with an editor state and computed by combining
// data from several fields. A typical use case is if one needs a data that
// relies on a server side information (like a synchronized array) which must be
// recomputed each time the selection (which is a field but is also an internal
// information of CodeMirror) is changed. An Aspect exposes a getter that
// handles all React's hooks shenanigans and an extension that must be added to
// the CodeMirror initial configuration.
export interface Aspect<A> extends Data<A, Facet<A, A>> { extension: Extension }

// An Aspect is recomputed each time its dependencies are updated. The
// dependencies of an Aspect is declared through a record, giving a name to each
// dependency.
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

// Helper function retrieving a dependency extension.
function getExtension<A>(dep: Dependency<A>): Extension {
  type Dep<A> = Dependency<A>;
  const asExt = (d: Dep<A>): boolean => Object.keys(d).includes('extension');
  const isAspect = (d: Dep<A>): d is Aspect<A> => asExt(d);
  if (isAspect(dep)) return dep.extension;
  else return dep.structure.extension;
}

// An Aspect is declared using its dependencies and a function. This function's
// input is a record containing, for each key of the dependencies record, a
// value of the type of the corresponding field. The function's output is a
// value of the aspect's type.
export function createAspect<I extends Dict, O>(
  deps: Dependencies<I>,
  fn: (input: I) => O,
): Aspect<O> {
  const init = fn(transformDict(deps, (d) => d.init) as I);
  const enables = mapDict(deps, getExtension);
  const combine: Combine<O> = (l) => l.length > 0 ? l[l.length - 1] : init;
  const facet = Facet.define<O, O>({ combine, enables });
  const get: Get<O> = (state) => state?.facet(facet) ?? init;
  const convertedDeps = mapDict(deps, (d) => d.structure);
  const compute: Get<O> = (s) => fn(transformDict(deps, (d) => d.get(s)) as I);
  const extension = facet.compute(convertedDeps, compute);
  return { init, get, structure: facet, extension };
}



// -----------------------------------------------------------------------------
//  Generic plugin interface
// -----------------------------------------------------------------------------

// Types declarations for event handlers. It is built on the same idea as the
// ones from CodeMirror, but our handlers are conceived as purely functionnal.
export type EventMap = HTMLElementEventMap;
export type Handler<S, E> = (s: S, e: E, v: EditorView) => S | undefined;
export type Handlers<S> = { [e in keyof EventMap]?: Handler<S, EventMap[e]> };

// The plugin interface contains all necessary definition to build a CodeMirror
// extension. However, it should be simpler to use and define for two reasons:
//  - everything is grouped under one unique interface, instead of CodeMirror
//    where it is divided between the PluginValue and PluginSpec interfaces.
//  - everything is intended as purely functionnal, avoiding mutable state is
//    always a good idea to make the code cleaner and easier to maintain.
//
// The interface is parameterized by the type of the plugin's internal state.
// Each plugin's method will interact with this state, and modifies it, in a
// functionnal manner, if needed.
//
// The interface's methods are as follows:
//  - create: instanciate the plugin internal state using the current editor
//    view. It is the only mandatory function.
//  - update: update the plugin's state according to a CodeMirror view update.
//  - destroy: cleanup function called when the plugin's state is destroyed.
//    Only useful if the state's creation is effectful.
//  - decorations: returns the decorations that should be added to the code by
//    CodeMirror.
//  - eventHandlers: a collection of callbacks used to react to DOM events.
export interface Plugin<State> {
  create: (view: EditorView) => State;
  update?: (state: State, update: ViewUpdate) => State;
  destroy?: (state: State) => void;
  decorations?: (state: State) => DecorationSet;
  eventHandlers?: Handlers<State>;
}

// Function used to convert a Plugin into a proper CodeMirror Extension.
// It only does plumbing to match the CodeMirror API.
export function buildExtension<S>(p: Plugin<S>): Extension {
  const { update: up, destroy, decorations: d } = p;
  const decorations = d && ((s: State): DecorationSet => d(s.state));
  class State {
    state: S;
    constructor(view: EditorView) { this.state = p.create(view); }
    update(v: ViewUpdate): void { if (up) this.state = up(this.state, v); }
    destroy(): void { if (destroy) destroy(this.state); }
  }
  let eventHandlers: DOMEventHandlers<State> | undefined = undefined;
  if (p.eventHandlers) {
    eventHandlers = {};
    for (const [event, handler] of Object.entries(p.eventHandlers)) {
      eventHandlers[event] = function(this, event, view) {
        const state = handler ? handler(this.state, event, view) : undefined;
        if (state) { this.state = state; view.dispatch(); return true; }
        return false;
      };
    }
  }
  return ViewPlugin.fromClass(State, { decorations, eventHandlers });
}



// -----------------------------------------------------------------------------
//  Utilitary types
// -----------------------------------------------------------------------------

// An alias type for functions and locations.
type Fct = string | undefined;
type Marker = Ast.marker | undefined;

// A Caller is just a pair of the caller's key and the statement's key where the
// call occurs.
type Caller = { fct: key<'#fct'>, marker: key<'#stmt'> };

// A range is just a pair of position in the code.
interface Range { from: number, to: number }



// -----------------------------------------------------------------------------
//  Tree datatype definition and utiliary functions
// -----------------------------------------------------------------------------

// The code is given by the server has a tree but implemented with arrays and
// without information on the ranges of each element. It will be converted in a
// good old tree that carry those information.
interface Tree extends Range { id?: string, children: Tree[] }

// A leaf tree with no children.
const leaf = (from: number, to: number): Tree => ({ from, to, children: [] });

// Convert an Ivette text (i.e a function's code) into a Tree, adding range
// information to each construction.
function textToTree(t: text): Tree | undefined {
  function aux(t: text, from: number): Tree | undefined {
    if (t === null) return undefined;
    if (typeof t === 'string') return leaf(from, from + t.length);
    const children: Tree[] = []; let acc = from;
    for (const child of t.slice(1)) {
      const node = aux(child, acc);
      if (node) { acc = node.to; children.push(node); }
    }
    if (children.length === 0) return undefined;
    const to = children[children.length - 1].to;
    const finalFrom = children[0].from;
    const id = typeof t[0] === 'string' && t[0][0] === '#' ? t[0] : undefined;
    return { id, from: finalFrom, to, children };
  }
  return aux(t, 0);
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
    if (tree.id) ranges.set(tree.id, tree);
    for (const child of tree.children) toRanges(child);
  };
  toRanges(tree);
  return ranges;
}

// Find the closest covering tagged node of a given position. Returns
// undefined if there is not relevant covering node.
function coveringNode(tree: Tree, pos: number): Tree | undefined {
  if (pos < tree.from || pos > tree.to) return undefined;
  if (pos === tree.from) return tree;
  const res = Utils.first(tree.children, (c) => coveringNode(c, pos));
  if (res) return res.id ? res : tree;
  if (tree.from <= pos && pos < tree.to) return tree;
  return undefined;
}

// Find the subtree whose root as the given marker as id, or undefined if it
// does not exists in the tree.
function findMarker(tree: Tree, marker: Marker): Tree | undefined {
  if (tree.id === marker) return tree;
  return Utils.first(tree.children, (c) => findMarker(c, marker));
}



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
const MarkerUpdater = EditorView.domEventHandlers({
  mouseup: (_, view) => {
    const fct = Fct.get(view.state);
    const tree = Tree.get(view.state);
    const update = UpdateSelection.get(view.state);
    const main = view.state.selection.main;
    const id = coveringNode(tree, main.from)?.id;
    update({ location: { fct, marker: Ast.jMarker(id) } });
  }
});



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
const HoveredUpdater = EditorView.domEventHandlers({
  mousemove: (event, view) => {
    const fct = Fct.get(view.state);
    const tree = Tree.get(view.state);
    const updateHovered = UpdateHovered.get(view.state);
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



// -----------------------------------------------------------------------------
//  Function code representation, general information and data structures
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
const Tree = createAspect({ t: Text }, ({ t }) => textToTree(t) ?? leaf(0, 0));

// This aspect computes the markers ranges of the currently displayed function's
// tree, represented by the <Tree> aspect.
const Ranges = createAspect({ t: Tree }, ({ t }) => markersRangesOfTree(t));

// This field contains the dead code information as inferred by Eva.
const Dead = createField<Eva.deadCode>({ unreachable: [], nonTerminating: [] });

// This field contains all the current function's callers, as inferred by Eva.
const Callers = createField<Caller[]>([]);

// This field contains information on markers.
type GetMarkerData = (key: string) => Ast.markerInfoData | undefined;
const GetMarkerData = createField<GetMarkerData>(() => undefined);



// -----------------------------------------------------------------------------
//  Representation of properties' information
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
  const deps = { statuses: PropertiesStatuses, ranges: Ranges };
  return createAspect(deps, ({ statuses, ranges }) => {
    type R = PropertyRange | undefined;
    const isDef = (r: R): r is PropertyRange => r !== undefined;
    const fn = (p: Properties.statusData): R => {
      const range = ranges.get(p.key);
      return range && { ...p, range };
    };
    return statuses.map(fn).filter(isDef);
  });
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



// -----------------------------------------------------------------------------
//  Plugin decorating hovered and selected elements
// -----------------------------------------------------------------------------

// The different kind of decorations used in this plugin.
const hoveredClass = Decoration.mark({ class: 'cm-hovered-code' });
const selectedClass = Decoration.mark({ class: 'cm-selected-code' });

// Plugin declaration.
const CodeDecorationPlugin: Plugin<DecorationSet> = {

  // There is no decoration or hovered/selected nodes in the initial state.
  create: () => RangeSet.empty,

  // We do not compute the decorations here, as it seems like CodeMirror calls
  // this method really often, which may be costly. We should actually benchmark
  // this to be sure that it is really necessary.
  decorations: (state) => state,

  // The selected nodes handling is done in this function.
  update: (_, u) => {
    const tree = Tree.get(u.state);
    const selectedMarker = Marker.get(u.state);
    const selected = selectedMarker && findMarker(tree, selectedMarker);
    const hoveredMarker = Hovered.get(u.state);
    const hovered = hoveredMarker && findMarker(tree, hoveredMarker);
    const range = selected && selectedClass.range(selected.from, selected.to);
    const add = hovered && [ hoveredClass.range(hovered.from, hovered.to) ];
    const set = range ? RangeSet.of(range) : RangeSet.empty;
    return set.update({ add, sort: true });
  },

};



// -----------------------------------------------------------------------------
//  Dead code decorations plugin
// -----------------------------------------------------------------------------

// The decorations used in this plugin.
const unreachableClass = Decoration.mark({ class: 'cm-dead-code' });
const nonTerminatingClass = Decoration.mark({ class: 'cm-non-term-code' });

// The plugin itself. The decorations are recomputed only once each time the
// selected function is changed.
const DeadCodePlugin: Plugin<DecorationSet> = {
  create: () => RangeSet.empty,
  decorations: (state) => state,
  update: (state, update) => {
    if (!update.docChanged) return state;
    const dead = Dead.get(update.state);
    const ranges = Ranges.get(update.state);
    const unreachable = [];
    for (const marker of dead.unreachable) {
      const r = ranges.get(marker); if (!r) continue;
      const range = unreachableClass.range(r.from, r.to);
      unreachable.push(range);
    }
    const nonTerm = [];
    for (const marker of dead.nonTerminating) {
      const r = ranges.get(marker); if (!r) continue;
      const range = nonTerminatingClass.range(r.from, r.to);
      nonTerm.push(range);
    }
    return RangeSet.of(unreachable.concat(nonTerm), true);
  },
};



// -----------------------------------------------------------------------------
//  Property bullets extension
// -----------------------------------------------------------------------------

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

// The properties gutter extension itself. For each line, it recovers the
// relevant markers in the code tree, retrieves the corresponding properties and
// builds the bullets.
const PropertiesGutter: Extension = gutter({
  class: 'cm-property-gutter',
  lineMarker(view, block) {
    const line = view.state.doc.lineAt(block.from);
    const start = line.from; const end = line.from + block.length;
    const ranges = PropertiesRanges.get(view.state);
    const inLine = (r: Range): boolean => start <= r.from && r.to <= end;
    function isHeader(r: Range): boolean {
      if (!line.text.includes('requires')) return false;
      const next = view.state.doc.line(line.number + 1);
      return r.from <= next.from && next.to <= r.to;
    }
    const prop = ranges.find((r) => inLine(r.range) || isHeader(r.range));
    if (!prop) return null;
    const propTags = PropertiesTags.get(view.state);
    const statusTag = propTags.get(prop.key);
    return statusTag ? new PropertyBullet(statusTag) : null;
  }
});



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

const ContextMenu = EditorView.domEventHandlers({
  contextmenu: (event, view) => {
    const tree = Tree.get(view.state);
    const locations = Callers.get(view.state);
    const updateSelection = UpdateSelection.get(view.state);
    const getMarkerData = GetMarkerData.get(view.state);
    const coords = { x: event.clientX, y: event.clientY };
    const position = view.posAtCoords(coords); if (!position) return;
    const node = coveringNode(tree, position);
    if (!node || !node.id) return;
    const items: Dome.PopupMenuItem[] = [];
    const info = getMarkerData(node.id);
    if (info?.var === 'function') {
      if (info.kind === 'declaration') {
        const callers = Dictionary.groupBy(locations, e => e.fct);
        Dictionary.forEach(callers, (e) => {
          const callerName = e[0].fct;
          const callSites = e.length > 1 ? `(${e.length} call sites)` : '';
          items.push({
            label: `Go to caller ${callerName} ` + callSites,
            onClick: () => updateSelection({
              name: `Call sites of function ${info.name}`,
              locations: locations,
              index: locations.findIndex(l => l.fct === callerName)
            })
          });
        });
      } else {
        const location = { fct: info.name };
        const onClick = (): void => updateSelection({ location });
        const label = `Go to definition of ${info.name}`;
        items.push({ label, onClick });
      }
    }
    const enabled = info?.kind === 'lvalue' || info?.var === 'variable';
    const onClick = (kind: access): void => {
      if (info && node.id)
        studia({ marker: node.id, info, kind }).then(updateSelection);
    };
    const reads = 'Studia: select reads';
    const writes = 'Studia: select writes';
    items.push({ label: reads, enabled, onClick: () => onClick('Reads') });
    items.push({ label: writes, enabled, onClick: () => onClick('Writes') });
    if (items.length > 0) Dome.popupMenu(items);
    return;
  }
});



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



// -----------------------------------------------------------------------------
//  AST View component
// -----------------------------------------------------------------------------

// Necessary extensions for our needs.
const baseExtensions: Extension[] = [
  Fct.structure.extension,
  Marker.structure.extension,
  UpdateSelection.structure.extension,
  MarkerUpdater,

  Hovered.structure.extension,
  UpdateHovered.structure.extension,
  HoveredUpdater,

  Text.structure.extension,
  Tree.extension,
  Ranges.extension,
  Dead.structure.extension,
  Callers.structure.extension,
  GetMarkerData.structure.extension,

  Tags.structure.extension,
  PropertiesStatuses.structure.extension,
  PropertiesRanges.extension,
  PropertiesTags.extension,
  PropertiesGutter,
  foldGutter(),

  buildExtension(CodeDecorationPlugin),
  buildExtension(DeadCodePlugin),
  ContextMenu,

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

  /*
  const getTaints = Eva.taintedLvalues;
  const taintReq = React.useMemo(() => Server.send(getTaints, fct), [fct]);
  const { result: taints } = Dome.usePromise(taintReq);

  if (taints && data) {
    console.log('-----');
    for (const taint of taints) {
      const range = data.ranges.get(taint.lval);
      console.log (taint.lval, range, taint.before, taint.after);
    }
    console.log('-----');
  }
  */

  return <div className='cm-global-box' ref={parent} />;
}



registerSandbox({
  id: 'codemirror6',
  label: 'CodeMirror 6',
  children: <Editor />,
});
