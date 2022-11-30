import React from 'react';
import Dictionary from 'lodash';
import { Annotation, Transaction } from '@codemirror/state';
import { Facet, StateField, EditorSelection } from '@codemirror/state';
import { EditorState, Extension, RangeSet } from '@codemirror/state';
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

const Debug = new Dome.Debug('CodeMirror6 AST View');



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
export type Get<A> = (state: EditorState) => A;
export type Set<A> = (view: EditorView | null, value: A) => void;
export type Equal<A> = (left: A, right: A) => boolean;
export type Update<A> = (current: A, transaction: Transaction) => A;
export interface Field<A> {
  init: A,
  get: Get<A>,
  set: Set<A>,
  field: StateField<A>
}

// A Field is simply declared using an initial value. However, to be able to
// use it, you must add its extension (obtained through <field.extension>) to
// the CodeMirror initial configuration. If determining equality between
// values of the given type cannot be done using (===), an equality test can be
// provided through the optional parameters <equal>.
export function createField<A>(initialValue: A, equal?: Equal<A>): Field<A> {
  const annot = Annotation.define<A>();
  const create = (): A => initialValue;
  const update: Update<A> = (current, tr) => tr.annotation(annot) ?? current;
  const field = StateField.define<A>({ create, update, compare: equal });
  const get: Get<A> = (state) => state.field(field);
  const set: Set<A> = (v, a) =>
    React.useEffect(() => v?.dispatch({ annotations: annot.of(a) }), [v, a]);
  return { init: initialValue, get, set, field };
}

// A custom field is provided for the current editor's selection. To use it, add
// its extension to the CodeMirror initial configuration.
export const Selection = createSelectionField();
function createSelectionField(): Field<EditorSelection> {
  const create = (state: EditorState): EditorSelection => state.selection;
  const update: Update<EditorSelection> = (curr, tr) => tr.selection ?? curr;
  const field = StateField.define<EditorSelection>({ create, update });
  const init = EditorSelection.single(0);
  const get: Get<EditorSelection> = state => state.field(field);
  const set: Set<EditorSelection> = (v, selection) =>
    React.useEffect(() => v?.dispatch({ selection }), [v, selection]);
  return { init, get, set, field };
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
//
// The underlying CodeMirror concept, which is called a Facet, can depends on
// other facets and on the document itself. For now, because we don't need it
// and because it would complexify the aspects' creation, aspects cannot depend
// on another aspect.
export interface Aspect<A> { get: Get<A>, extension: Extension }

// An Aspect is recomputed each time its dependencies are updated. The
// dependencies of an Aspect is declared through a record, giving a name to each
// dependency.
export type Dict = Record<string, any>;
export type Dependencies<I extends Dict> = { [K in keyof I]: Field<I[K]> };

// An Aspect is declared using its dependencies and a function. This function's
// input is a record containing, for each key of the dependencies record, a
// value of the type of the corresponding field. The function's output is a
// value of the aspect's type.
export function createAspect<Input extends Dict, Output>(
  deps: Dependencies<Input>,
  fn: (input: Input) => Output,
): Aspect<Output> {
  const inputInit: Dict = {};
  for (const key in deps) inputInit[key] = deps[key].init;
  const init = fn(inputInit as Input);
  type Combine = (l: readonly Output[]) => Output;
  const combine: Combine = (l) => l.length > 0 ? l[l.length - 1] : init;
  const facet = Facet.define<Output, Output>({ combine });
  const get: Get<Output> = (state) => state.facet(facet);
  type CodeMirrorDependency = 'doc' | 'selection' | StateField<any>;
  const convertedDeps: CodeMirrorDependency[] = [];
  for (const key in deps) convertedDeps.push(deps[key].field);
  const extension = facet.compute(convertedDeps, (state) => {
    const input: Dict = {}
    for (const key in deps) input[key] = deps[key].get(state);
    return fn(input as Input);
  });
  return { get, extension };
}



// -----------------------------------------------------------------------------
//  Code extraction
// -----------------------------------------------------------------------------

// A range is just a pair of position in the code.
interface Range { from: number, to: number }

// The code is given by the server has a tree but implemented with arrays and
// without information on the ranges of each element. It will be converted in a
// good old tree that carry those information.
interface Tree extends Range { id?: string, children: Tree[] }

// Find the closest covering tagged node of a given position. Returns
// undefined if there is not relevant covering node.
function coveringNode(tree: Tree, position: number): Tree | undefined {
  if (position < tree.from || position > tree.to) return undefined;
  if (position === tree.from) return tree;
  for (const child of tree.children) {
    const res = coveringNode(child, position);
    if (res) return res.id ? res : tree;
  }
  if (tree.from <= position && position < tree.to) return tree;
  return undefined;
}

// A Caller is just a pair of the caller's key and the statement's key where the
// call occurs.
type Caller = { fct: key<'#fct'>, marker: key<'#stmt'> };

// Recovers all the given function's callers.
async function functionCallers(fct: string | undefined): Promise<Caller[]> {
  try {
    const data = await Server.send(Eva.getCallers, fct);
    const locations = data.map(([fct, marker]) => ({ fct, marker }));
    return locations;
  } catch (err) {
    Debug.error(`Fail to retrieve callers of function '${fct}':`, err);
    return [];
  }
}

// This interface carries all the needed information on the code that we have to
// display. The carried information are as follows:
//  - the function name,
//  - the code itself, view as a plain string to be displayed by codemirror,
//  - the code AST, represented using the Tree type described above,
//  - a map from markers to ranges in the code, used by extensions to simply
//    target elements in the code to modify.
interface CodeData {
  fct?: string,
  code: string,
  tree: Tree,
  dead: Eva.deadCode,
  callers: Caller[],
  ranges: Map<string, Range>
}

// Empty code data for initialization.
const emptyCodeData = {
  code: '',
  tree: { from: 0, to: 0, children: [] },
  dead: { unreachable: [], nonTerminating: [] },
  callers: [],
  ranges: new Map()
};

// Compute code data from a function name. If the given function name is not
// valid, default information are returned, i.e the code contains an error
// message, the tree is simply an irrelevant untagged node covering all the code
// range, and the markers map is empty.
async function extractCodeData(fct?: string): Promise<CodeData> {
  // Flatten the AST given by the server, ignoring the tags.
  const toString = (text: text): string => {
    if (Array.isArray(text)) return text.slice(1).map(toString).join('');
    else if (typeof text === 'string') return text;
    else return 'Failed to convert text to string';
  };
  // Dive through the AST to build a structured tree, computing the ranges for
  // every element. The id is used to keep track of the tags. An undefined id
  // means that the node is not a tagged element and should not be considered by
  // relevant extensions.
  const toTree = (t: text, from: number): Tree | undefined => {
    if (Array.isArray(t)) {
      const children = Array<Tree>(); let acc = from;
      for (const child of t.slice(1)) {
        const node = toTree(child, acc);
        if (node) { acc = node.to; children.push(node); }
      }
      if (children.length === 0) return undefined;
      const to = children[children.length - 1].to;
      const finalFrom = children[0].from;
      const id = typeof t[0] === 'string' && t[0][0] === '#' ? t[0] : undefined;
      return { id, from: finalFrom, to, children };
    }
    else if (typeof t === 'string')
      return { from, to: from + t.length, children: [] };
    else return undefined;
  };
  // Dive through the tree to build a map from tags to ranges.
  const toRanges = (tree: Tree, map: Map<string, Range>): void => {
    if (tree.id) map.set(tree.id, tree);
    for (const child of tree.children) toRanges(child, map);
  };
  // Request the AST and compute all relevent information.
  try {
    const text = await Server.send(Ast.printFunction, fct);
    const code = toString(text);
    const tree = toTree(text, 0) ?? { from: 0, to: code.length, children: [] };
    const dead = await Server.send(Eva.getDeadCode, fct);
    const callers = await functionCallers(fct);
    const ranges = new Map<string, Range>();
    toRanges(tree, ranges);
    return { fct, code, tree, dead, callers, ranges };
  } catch (e) {
    Debug.error(`Failed with ${e}`);
    return emptyCodeData;
  }
}



// -----------------------------------------------------------------------------
//  AST View inputs
// -----------------------------------------------------------------------------

// The code data are available for CodeMirror plugins through this input.
const CodeData = createField<CodeData>(emptyCodeData);

// The Ivette selection must be updated by CodeMirror plugins. This input
// add the callback in the CodeMirror internal state.
type UpdateSelection = (a: States.SelectionActions) => void;
const UpdateSelection = createField<UpdateSelection>(() => { return; });

// The Ivette hovered element must be updated by CodeMirror plugins. This
// input add the callback in the CodeMirror internal state.
type UpdateHovered = (h: States.Hovered) => void;
const UpdateHovered = createField<UpdateHovered>(() => { return ; });

// This input adds information on properties' tags into the CodeMirror state.
type StatusDict = Map<string, States.Tag>;
const StatusDict = createField<StatusDict>(new Map());

// The component needs information on markers' status data. To improve
// performances, they are transformed into a map by a State Data each time they
// are updated.
type StatusDataMap = Map<string, Properties.statusData>;
const StatusDataList = createField<Properties.statusData[]>([]);
const StatusDataMap = createAspect({ list: StatusDataList }, (input) => {
  const res: StatusDataMap = new Map();
  input.list.forEach(p => res.set(p.key, p));
  return res;
});

// Plugins need to be able to retrieve information on markers.
type GetMarkerData = (key: string) => Ast.markerInfoData | undefined;
const GetMarkerData = createField<GetMarkerData>(() => undefined);

// The selected nodes aspect's dependencies.
const SelectedTreesDeps = {
  data: CodeData,
  update: UpdateSelection,
  selection: Selection
};

// The selected nodes in the AST. It is recomputed each time a selection
// transaction is performed, or when either CodeData or UpdateSelection inputs
// are updated. We need to separate this computation from the plugins to avoid
// triggering a CodeMirror's update during another update.
const SelectedTrees = createAspect(SelectedTreesDeps, (input) => {
  const { tree } = input.data;
  const ranges = input.selection.ranges;
  const coverings = ranges.map((s) => coveringNode(tree, s.from));
  const isTree = (c: Tree | undefined): c is Tree => !!c;
  return coverings.filter(isTree).filter((c) => c.id);
});



// -----------------------------------------------------------------------------
//  Plugin decorating hovered and selected elements
// -----------------------------------------------------------------------------

// The different kind of decorations used in this plugin.
const hoveredClass = Decoration.mark({ class: 'cm-hovered-code' });
const selectedClass = Decoration.mark({ class: 'cm-selected-code' });

// Internal state of the plugin.
interface CodeDecorationState {
  decorations: DecorationSet; // Decorations to be added to the code
  selected: Tree[];           // Currently selected nodes
  hovered?: Tree;             // Currently hovered node
}

// Internal function used to recompute the plugin's decorations. The function is
// called by the plugin only when needed, i.e when the hovered or selected nodes
// have actually changed.
function computeDecorations(state: CodeDecorationState): CodeDecorationState {
  const { hovered, selected } = state;
  const ranges = selected.map(s => selectedClass.range(s.from, s.to));
  const add = hovered && [ hoveredClass.range(hovered.from, hovered.to) ];
  const decorations = RangeSet.of(ranges).update({ add, sort: true });
  return { ...state, decorations };
}

// Plugin declaration.
const CodeDecorationPlugin: Plugin<CodeDecorationState> = {

  // There is no decoration or hovered/selected nodes in the initial state.
  create: () => ({ decorations: RangeSet.empty, selected: [] }),

  // We do not compute the decorations here, as it seems like CodeMirror calls
  // this method really often, which may be costly. We should actually benchmark
  // this to be sure that it is really necessary.
  decorations: (state) => state.decorations,

  // The selected nodes handling is done in this function.
  update: (state, update) => {
    if (!update.selectionSet) return state;
    const selected = SelectedTrees.get(update.state); 
    return computeDecorations({ ...state, selected });
  },

  // The hovered handling is done through the mousemove callback. The code is
  // similar to the update method. It also update the global ivette's hovered
  // element.
  eventHandlers: {
    mousemove: (state, event, view) => {
      const { fct, tree } = CodeData.get(view.state);
      const updateHovered = UpdateHovered.get(view.state);
      const backup = (): CodeDecorationState => {
        updateHovered(undefined);
        return computeDecorations({ ...state, hovered: undefined });
      };
      const coords = { x: event.clientX, y: event.clientY };
      const pos = view.posAtCoords(coords); if (!pos) return backup();
      const hov = coveringNode(tree, pos); if (!hov) return backup();
      const from = view.coordsAtPos(hov.from); if (!from) return backup();
      const to = view.coordsAtPos(hov.to); if (!to) return backup();
      const left = Math.min(from.left, to.left);
      const right = Math.max(from.left, to.left);
      const top = Math.min(from.top, to.top);
      const bottom = Math.max(from.bottom, to.bottom);
      const horizontallyOk = left <= coords.x && coords.x <= right;
      const verticallyOk = top <= coords.y && coords.y <= bottom;
      if (!horizontallyOk || !verticallyOk) return backup();
      const marker = Ast.jMarker(hov?.id);
      updateHovered(marker ? { fct, marker } : undefined);
      return computeDecorations({ ...state, hovered: hov });
    }
  }

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
    const { dead, ranges } = CodeData.get(update.state);
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

// Extension modifying the default gutter theme.
const gutterTheme: Extension = EditorView.baseTheme({
  '.cm-gutters': {
    borderRight: '0px',
    width: '2.15em',
    background: 'var(--background-report)',
  }
});


// Find the head nodes contained in a given range or only starting in it but
// with an id.
function containedNodes(tree: Tree, range: Range): Tree[] {
  if (range.from <= tree.from && tree.from <= range.to && tree.id)
    return [ { ...tree, children: [] } ];
  return tree.children.map((child) => containedNodes(child, range)).flat();
}

// Returns all the ids contained in a tree.
function getIds(tree: Tree): string[] {
  return (tree.id ? [tree.id] : []).concat(tree.children.map(getIds).flat());
}

// The properties gutter extension itself. For each line, it recovers the
// relevant markers in the code tree, retrieves the corresponding properties and
// builds the bullets.
const PropertiesExtension: Extension = gutter({
  class: 'cm-bullet',
  lineMarker(view, line) {
    const { tree } = CodeData.get(view.state);
    const statusDict = StatusDict.get(view.state);
    const propertiesMap = StatusDataMap.get(view.state);
    const lineRange = { from: line.from, to: line.from + line.length };
    const nodes = containedNodes(tree, lineRange);
    let property: Properties.statusData | undefined = undefined;
    for (const node of nodes) {
      for (const id of getIds(node)) {
        property = propertiesMap.get(id);
        if (property) break;
      }
      if (property) break;
    }
    if (!property) return null;
    const status = statusDict.get(property.status);
    return new PropertyBullet(status);
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
//  Context menu plugin
// -----------------------------------------------------------------------------

const ContextMenuPlugin: Plugin<void> = {
  create: () => { return; },
  eventHandlers: {
    contextmenu: (_, event, view) => {
      const { tree, callers: locations } = CodeData.get(view.state);
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
  }
};



// -----------------------------------------------------------------------------
//  Code highlighting and parsing
// -----------------------------------------------------------------------------

// Plugin specifying how to highlight the code. The theme is handled by the CSS.
const HighlightPlugin = syntaxHighlighting(HighlightStyle.define([
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
//  AST View component
// -----------------------------------------------------------------------------

// Necessary extensions for our needs.
const baseExtensions: Extension[] = [
  Selection.field.extension,
  SelectedTrees.extension,
  UpdateHovered.field.extension,
  UpdateSelection.field.extension,
  CodeData.field.extension,
  buildExtension(CodeDecorationPlugin),
  buildExtension(DeadCodePlugin),
  StatusDict.field.extension,
  StatusDataList.field.extension,
  StatusDataMap.extension,
  gutterTheme, PropertiesExtension,
  GetMarkerData.field.extension,
  buildExtension(ContextMenuPlugin),
  foldGutter(),
  HighlightPlugin,
  new LanguageSupport(cppLanguage),
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
  const [_, updateHovered] = States.useHovered();
  UpdateHovered.set(editor.current, updateHovered);

  // Updating CodeMirror when the <properties> synchronized array is changed.
  const properties = States.useSyncArray(Properties.status).getArray();
  StatusDataList.set(editor.current, properties);

  // Updating CodeMirror when the <propStatusTags> map is changed.
  const statusDict = States.useTags(Properties.propStatusTags);
  StatusDict.set(editor.current, statusDict);

  // Updating CodeMirror when the <markersInfo> synchronized array is changed.
  const info = States.useSyncArray(Ast.markerInfo);
  const getMarkerData = React.useCallback((key) => info.getData(key), [info]);
  GetMarkerData.set(editor.current, getMarkerData);

  // Retrieving data on currently selected function and updating CodeMirror when
  // they have changed.
  const fct = selection?.current?.fct;
  const dataReq = React.useMemo(() => extractCodeData(fct), [fct]);
  const { result: data } = Dome.usePromise(dataReq);
  CodeData.set(editor.current, data ?? emptyCodeData);
  React.useEffect(() => {
    if (!editor.current || !data) return;
    const length = editor.current.state.doc.length;
    const changes = { from: 0, to: length, insert: data.code };
    editor.current.dispatch({ changes, selection: { anchor: 0 } });
  }, [editor, data]);

  // Updating the CodeMirror's selected marker.
  React.useEffect(() => {
    const view = editor.current; if (!view || !data) return;
    if (selection.current && selection.current.marker) {
      const r = data.ranges.get(selection.current.marker);
      if (r) view.dispatch({ selection: { anchor: r.from } });
    }
  }, [editor, data, selection]);

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
