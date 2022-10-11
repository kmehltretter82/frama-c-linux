import React from 'react';
import Dictionary from 'lodash';
import { cpp } from '@codemirror/lang-cpp';
import { Facet, StateField, StateEffect } from '@codemirror/state';
import { EditorState, Extension, RangeSet } from '@codemirror/state';
import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { DOMEventHandlers, GutterMarker, gutter } from '@codemirror/view';
import { Decoration, DecorationSet, drawSelection } from '@codemirror/view';

import { tags } from '@lezer/highlight';
import { syntaxHighlighting, HighlightStyle } from '@codemirror/language';

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

const Debug = new Dome.Debug('AST View');



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

// Internal function used to convert a Plugin into a proper CodeMirror
// Extension. It only does plumbing to match the CodeMirror API.
function buildExtension<S>(p: Plugin<S>): Extension {
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

// Helper for facets that only keep tracks of server's data in the CodeMirror
// state. Each time we have to combine different values for the facet, we
// simply keep that last one.
function stateFacet<I>(e: I): Facet<I, I> {
  const combine = (l: readonly I[]): I => l.length > 1 ? l[l.length - 1] : e;
  return Facet.define<I, I>({ combine });
}



// -----------------------------------------------------------------------------
//  Code extraction
// -----------------------------------------------------------------------------

// A range is just a pair of position in the code.
interface Range { from: number, to: number }

// Test if a range is contained by another.
function isBetween(inside: Range, outside: Range): boolean {
  return outside.from <= inside.from && inside.to <= outside.to;
}

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
  return tree;
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
  ranges: Map<string, Range>
}

// Empty code data for initialization.
const emptyTree = { from: 0, to: 0, children: [] };
const emptyCodeData = { code: '', tree: emptyTree, ranges: new Map() };

// The code data are available for CodeMirror plugins through this facet.
const CodeDataFacet = stateFacet<CodeData>(emptyCodeData);

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
  const request = Server.send(Ast.printFunction, fct);
  const text = await request.catch(e => `Failed with ${e}`);
  const code = toString(text);
  const tree = toTree(text, 0) ?? { from: 0, to: code.length, children: [] };
  const ranges = new Map<string, Range>();
  toRanges(tree, ranges);
  return { fct, code, tree, ranges };
}



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

  // Only the selected nodes handling is done in this function. For each
  // selected range, we compute the covering tagged node, replacing the selected
  // nodes by them in the new state. We also update the global ivette's
  // selection.
  update: (state, update) => {
    if (!update.selectionSet) return state;
    const { fct, tree } = update.state.facet(CodeDataFacet);
    const selected = [];
    const meta = update.state.selection.ranges.length > 1;
    for (const selection of update.state.selection.ranges) {
      const covering = coveringNode(tree, selection.from);
      if (!covering || !covering.id) continue;
      selected.push(covering);
      const marker = Ast.jMarker(covering.id);
      States.setSelection({ fct: fct, marker }, meta);
    }
    return computeDecorations({ ...state, selected });
  },

  // The hovered handling is done through the mousemove callback. The code is
  // similar to the update method. It also update the global ivette's hovered
  // element.
  eventHandlers: {
    mousemove: (state, event, view) => {
      const { fct, tree } = view.state.facet(CodeDataFacet);
      const coords = { x: event.clientX, y: event.clientY };
      const position = view.posAtCoords(coords); if (!position) return state;
      const hovered = coveringNode(tree, position);
      if (!hovered || !hovered.id) return state;
      const marker = Ast.jMarker(hovered.id);
      States.setHovered(marker ? { fct, marker } : undefined);
      return computeDecorations({ ...state, hovered });
    }
  }

};



// -----------------------------------------------------------------------------
//  Dead code decorations plugin
// -----------------------------------------------------------------------------

// The decorations used in this plugin.
const unreachableClass = Decoration.mark({ class: 'cm-dead-code' });
const nonTerminatingClass = Decoration.mark({ class: 'cm-non-term-code' });

// The dead code data given by the server are available through this facet.
const noDeadCode = { unreachable: [], nonTerminating: [] };
const DeadCodeFacet = stateFacet<Eva.deadCode>(noDeadCode);

// As we want to avoid converting the dead code information given by the server
// to ranges at each update, we use a StateField to store the converted view of
// those information. This StateField is only computed when the document
// changes. To implement this, we first need a type to represent the dead code
// information as ranges.
type DeadCodeRanges = { unreachable: Range[], nonTerminating: Range[] };

// Then, we need a helper function that computes the ranges from the editor
// state. It retrieves the needed facets and does the conversion into ranges.
function computeDeadCodeRanges(state: EditorState): DeadCodeRanges {
  const { ranges } = state.facet(CodeDataFacet);
  const deadCode = state.facet(DeadCodeFacet);
  const unreachable: Range[] = [];
  deadCode.unreachable.forEach(marker => {
    const r = ranges.get(marker); if (!r) return;
    unreachable.push(r);
  });
  const nonTerminating: Range[] = [];
  deadCode.nonTerminating.forEach(marker => {
    const r = ranges.get(marker); if (!r) return;
    nonTerminating.push(r);
  });
  return { unreachable, nonTerminating };
}

// Finally, we can define the dead code ranges StateField.
const DeadCodeRanges = StateField.define<DeadCodeRanges>({
  create: (state) => computeDeadCodeRanges(state),
  update: (ranges, transaction) => {
    if (!transaction.docChanged) return ranges
    return computeDeadCodeRanges(transaction.state);
  },
});

// Internal state of the plugin. The <unreachable> and <nonTerminating> fields
// are used as cache to avoid converting over and over dead markers to ranges.
interface DeadCodeState { decorations: DecorationSet }

// Plugin declaration.
const DeadCodePlugin: Plugin<DeadCodeState> = {

  create: () => ({ decorations: RangeSet.empty }),

  decorations: (state) => state.decorations,

  // TODO: Do stuff only for relevant events.
  update: (state, update) => {
    const deadCode = update.state.field(DeadCodeRanges);
    const visible = update.view.visibleRanges;
    const keep = (i: Range): boolean => visible.some(o => isBetween(i, o));
    const unreachable = deadCode.unreachable.filter(keep)
      .map(r => unreachableClass.range(r.from, r.to));
    const nonTerm = deadCode.nonTerminating.filter(keep)
      .map(r => nonTerminatingClass.range(r.from, r.to));
    const decorations = RangeSet.of(unreachable.concat(nonTerm), true);
    return { ...state, decorations };
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

// This extension need information on the properties. Those facets add those
// information in the CodeMirror internal state.
const PropertiesFacet = stateFacet<Properties.statusData[]>([]);
const StatusDictFacet = stateFacet<Map<string, States.Tag>>(new Map());

type RangesGutterMarkers = [Range, GutterMarker][];

function computeRangesGuttersMarkers(state: EditorState): RangesGutterMarkers {
  const { ranges } = state.facet(CodeDataFacet);
  const statusDict = state.facet(StatusDictFacet);
  const properties = state.facet(PropertiesFacet);
  const rangesGutterMarkers: RangesGutterMarkers = [];
  for (const data of properties) {
    const marker = ranges.get(data.key); if (!marker) continue;
    const status = statusDict.get(data.status);
    const bullet = document.createElement('div');
    bullet.innerHTML = '◉'
    if (status) {
      bullet.style.color = getBulletColor(status);
      bullet.style.textAlign = 'center';
      if (status.descr) bullet.title = status.descr;
    }
    const tag = new class extends GutterMarker { toDOM() { return bullet; } };
    rangesGutterMarkers.push([marker, tag]);
  }
  return rangesGutterMarkers;
}

const RangesGutterMarkers = StateField.define<RangesGutterMarkers>({
  create: (state) => computeRangesGuttersMarkers(state),
  update: (markers, transaction) => {
    if (!transaction.docChanged) return markers;
    return computeRangesGuttersMarkers(transaction.state);
  }
});

const PropertiesExtension: Extension = gutter({
  class: 'cm-bullet',
  markers: (view) => {
    const ranges = view.state.field(RangesGutterMarkers);
    const res = RangeSet.of(ranges.map(([r, bullet]) => {
      return bullet.range(view.lineBlockAt(r.from).from);
    }), true);
    return res;
  },
});

// Extension modifying the default gutter theme.
const gutterTheme: Extension = EditorView.baseTheme({
  '.cm-gutters': {
    borderRight: '1px solid var(--code-bullet)',
    width: '2.0em',
    background: 'var(--background-report)',
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
//  Function callers
// -----------------------------------------------------------------------------

type Caller = { fct: key<'#fct'>, marker: key<'#stmt'> };

async function functionCallers(functionName: string): Promise<Caller[]> {
  try {
    const data = await Server.send(Eva.getCallers, functionName);
    const locations = data.map(([fct, marker]) => ({ fct, marker }));
    return locations;
  } catch (err) {
    Debug.error(`Fail to retrieve callers of function '${functionName}':`, err);
    return [];
  }
}



// -----------------------------------------------------------------------------
//  Context menu plugin
// -----------------------------------------------------------------------------

type UpdateSelection = (a: States.SelectionActions) => void;
type GetMarkerInfoData = (key: string) => Ast.markerInfoData | undefined;

const CallersFacet = stateFacet<Caller[]>([]);
const UpdateSelectionFacet = stateFacet<UpdateSelection>(() => { return; });
const GetMarkerInfoDataFacet = stateFacet<GetMarkerInfoData>(() => undefined);

const ContextMenuPlugin: Plugin<void> = {
  create: () => { return; },
  eventHandlers: {
    contextmenu: (_, event, view) => {
      const { tree } = view.state.facet(CodeDataFacet);
      const locations = view.state.facet(CallersFacet);
      const updateSelection = view.state.facet(UpdateSelectionFacet);
      const getMarkerInfoData = view.state.facet(GetMarkerInfoDataFacet);
      const coords = { x: event.clientX, y: event.clientY };
      const position = view.posAtCoords(coords); if (!position) return;
      const node = coveringNode(tree, position);
      if (!node || !node.id) return;
      const items: Dome.PopupMenuItem[] = [];
      console.log(getMarkerInfoData);
      const info = getMarkerInfoData(node.id);
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
}



// -----------------------------------------------------------------------------
//  Code highlighting
// -----------------------------------------------------------------------------

const HighlightPlugin = syntaxHighlighting(HighlightStyle.define([
  { tag: tags.comment, class: 'cm-comment' },
  { tag: tags.typeName, class: 'cm-type' },
  { tag: tags.number, class: 'cm-number' },
  { tag: tags.controlKeyword, class: 'cm-keyword' },
  { tag: tags.definition(tags.variableName) , class: 'cm-def' },
]));



// -----------------------------------------------------------------------------
//  AST View component
// -----------------------------------------------------------------------------

function Editor(): JSX.Element {

  // State infos used to decide which function to print.
  const printed = React.useRef<string | undefined>();
  const [selection, updateSelection] = States.useSelection();
  const fct = selection?.current?.fct;

  // Sync arrays for properties and context menus.
  const properties = States.useSyncArray(Properties.status).getArray();
  const statusDict = States.useTags(Properties.propStatusTags);
  const markersInfo = States.useSyncArray(Ast.markerInfo);

  // Necessary extensions for our needs.
  const [baseExtensions] = React.useState<Extension[]>(() => {
    return [
      drawSelection(),
      EditorState.allowMultipleSelections.of(true),
      HighlightPlugin,
      cpp(),

      CodeDataFacet.of(emptyCodeData),
      buildExtension(CodeDecorationPlugin),

      DeadCodeFacet.of(noDeadCode),
      DeadCodeRanges.extension,
      buildExtension(DeadCodePlugin),

      PropertiesFacet.of([]),
      StatusDictFacet.of(new Map()),
      RangesGutterMarkers.extension,
      gutterTheme, PropertiesExtension,

      CallersFacet.of([]),
      UpdateSelectionFacet.of(updateSelection),
      GetMarkerInfoDataFacet.of(markersInfo.getData),
      buildExtension(ContextMenuPlugin),
    ];
  });

  // Creating the codemirror vue and binding it to the editor div.
  const parent = React.useRef(null);
  const editor = React.useRef<EditorView | null>(null);
  React.useEffect(() => {
    if (!parent.current) return;
    const state = EditorState.create({ extensions: baseExtensions });
    editor.current = new EditorView({ state, parent: parent.current });
  }, [parent, baseExtensions]);

  // Callback function called when the focused function changes.
  const focusCallback = React.useCallback(async () => {
    const view = editor.current; if (!view) return;
    const data = await extractCodeData(fct);
    const deadCode = await Server.send(Eva.getDeadCode, fct);
    const locations = await functionCallers(fct ?? '');
    const code = CodeDataFacet.of(data);
    const dead = DeadCodeFacet.of(deadCode);
    const propertiesFacet = PropertiesFacet.of(properties);
    const statusDictFacet = StatusDictFacet.of(statusDict);
    const callersFacet = CallersFacet.of(locations);
    const getMarkerInfoData = GetMarkerInfoDataFacet.of(markersInfo.getData);
    printed.current = fct;
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: data.code },
      selection: { anchor: 0 },
      effects: [
        StateEffect.appendConfig.of(code),
        StateEffect.appendConfig.of(dead),
        StateEffect.appendConfig.of(propertiesFacet),
        StateEffect.appendConfig.of(statusDictFacet),
        StateEffect.appendConfig.of(callersFacet),
        StateEffect.appendConfig.of(getMarkerInfoData),
      ]
    });
  }, [editor, fct, properties, statusDict]);

  // Update the component when the focused function changes.
  React.useEffect(() => {
    if (printed.current !== fct) focusCallback();
    Server.onSignal(Ast.changed, focusCallback);
    return () => { Server.offSignal(Ast.changed, focusCallback); };
  });

  return <div className='cm-global-box' ref={parent} />;
}



registerSandbox({
  id: 'codemirror6',
  label: 'CodeMirror 6',
  children: <Editor />,
});
