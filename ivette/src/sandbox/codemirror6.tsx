import React from 'react';
import { DOMEventHandlers } from '@codemirror/view';
import { EditorState, Extension, RangeSet } from '@codemirror/state';
import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { Decoration, DecorationSet, drawSelection } from '@codemirror/view';

import { deadCode, getDeadCode } from 'frama-c/plugins/eva/api/general';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import { text } from 'frama-c/kernel/api/data';

import { registerSandbox } from 'ivette';

import './dark-code.css';



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
// The interface is parameterized by two types. The type <Data> is the type of
// all the data that are needed to instanciate the plugin. The type <State> is
// the internal state of the plugin. Each plugin's method will interact with
// this state, and modifies it, in a functionnal manner, if needed.
//
// The interface's methods are as follows:
//  - create: instanciate the plugin internal state using data and the current
//    editor view. It is the only mandatory function.
//  - update: update the plugin's state according to a CodeMirror view update.
//  - destroy: cleanup function called when the plugin's state is destroyed.
//    Only useful if the state's creation is effectful.
//  - decorations: returns the decorations that should be added to the code by
//    CodeMirror.
//  - eventHandlers: a collection of callbacks used to react to DOM events.
export interface Plugin<Data, State> {
  create: (data: Data, view: EditorView) => State;
  update?: (state: State, update: ViewUpdate) => State;
  destroy?: (state: State) => void;
  decorations?: (state: State) => DecorationSet;
  eventHandlers?: Handlers<State>;
}

// Internal function used to convert a Plugin into a proper CodeMirror
// Extension. It only does plumbing to match the CodeMirror API.
function buildExtension<D, S>(data: D, p: Plugin<D, S>): Extension {
  const { update: up, destroy, decorations: d } = p;
  const decorations = d && ((s: State): DecorationSet => d(s.state));
  class State {
    state: S;
    constructor(view: EditorView) { this.state = p.create(data, view); }
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
  hovered: Tree | undefined;  // Currently hovered node
  selected: Tree[];           // Currently selected nodes
  fct?: string;               // Currently selected function name
  tree: Tree;                 // Function AST
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
const CodeDecorationPlugin: Plugin<CodeData, CodeDecorationState> = {

  // The function's name and AST are given by the initialization data. There is
  // no decoration or hovered/selected nodes in the initial state.
  create: (data) => ({
    decorations: RangeSet.empty,
    hovered: undefined,
    selected: [],
    fct: data.fct,
    tree: data.tree,
  }),

  // Only the selected nodes handling is done in this function. For each
  // selected range, we compute the covering tagged node, replacing the selected
  // nodes by them in the new state. We also update the global ivette's
  // selection.
  update: (state, update) => {
    if (!update.selectionSet) return state;
    const selected = [];
    const meta = update.state.selection.ranges.length > 1;
    for (const selection of update.state.selection.ranges) {
      const covering = coveringNode(state.tree, selection.from);
      if (!covering || !covering.id) continue;
      selected.push(covering);
      const marker = Ast.jMarker(covering.id);
      States.setSelection({ fct: state.fct, marker }, meta);
    }
    return computeDecorations({ ...state, selected });
  },

  // We do not compute the decorations here, as it seems like CodeMirror calls
  // this method really often, which may be costly. We should actually benchmark
  // this to be sure that it is really necessary.
  decorations: (state) => state.decorations,

  // The hovered handling is done through the mousemove callback. The code is
  // similar to the update method. It also update the global ivette's hovered
  // element.
  eventHandlers: {
    mousemove: (state, event, view) => {
      const coords = { x: event.clientX, y: event.clientY };
      const position = view.posAtCoords(coords); if (!position) return state;
      const hovered = coveringNode(state.tree, position);
      if (!hovered || !hovered.id) return state;
      const marker = Ast.jMarker(hovered.id);
      States.setHovered(marker ? { fct: state.fct, marker } : undefined);
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

// Internal state of the plugin.
interface DeadCodeState {
  decorations: DecorationSet;
  unreachable: Range[];
  nonTerminating: Range[];
  fct?: string;
  deadCode: deadCode;
  ranges: Map<string, Range>;
}

// Data neeeded for the plugin initialization.
interface DeadCodeInit extends CodeData { deadCode: deadCode }



function mapFilter<X, Y>(f: (x: X) => Y | undefined, xs: X[]): Y[] {
  const ys: Y[] = [];
  for (const x of xs) { const y = f(x); if(y) ys.push(y); }
  return ys;
}


// Plugin declaration.
const DeadCodePlugin: Plugin<DeadCodeInit, DeadCodeState> = {

  create: (init) => ({
    decorations: RangeSet.empty,
    unreachable: mapFilter(init.ranges.get, init.deadCode.unreachable),
    nonTerminating: mapFilter(init.ranges.get, init.deadCode.nonTerminating),
    fct: init.fct,
    deadCode: init.deadCode,
    ranges: init.ranges,
  }),

  decorations: (state) => state.decorations,

  update: (state, update) => {
    console.log(state);
    const visible = update.view.visibleRanges;
    const keep = (i: Range): boolean => visible.some(o => isBetween(i, o));
    const unreachable = state.unreachable.filter(keep).map(r => unreachableClass.range(r.from, r.to));
    const nonTerminating = state.nonTerminating.filter(keep).map(r => nonTerminatingClass.range(r.from, r.to));
    const decorations = RangeSet.of(unreachable).update({ add: nonTerminating });
    return { ...state, decorations };
  },

}



// -----------------------------------------------------------------------------
//  AST View component
// -----------------------------------------------------------------------------

function Editor(): JSX.Element {

  // Necessary extensions for our needs
  const [baseExtensions] = React.useState<Extension[]>(() => {
    const multipleSelections = EditorState.allowMultipleSelections.of(true);
    const drawSelectionExt = drawSelection();
    return [multipleSelections, drawSelectionExt];
  });

  // Creating the codemirror vue and binding it to the editor div
  const parent = React.useRef(null);
  const editor = React.useRef<EditorView | null>(null);
  React.useEffect(() => {
    if (!parent.current) return;
    const state = EditorState.create({ extensions: baseExtensions });
    editor.current = new EditorView({ state, parent: parent.current });
  }, [parent, baseExtensions]);

  // State infos used to decide which function to print
  const printed = React.useRef<string | undefined>();
  const [selection] = States.useSelection();
  const fct = selection?.current?.fct;

  // Callback function called when the focused function changes
  const focusCallback = React.useCallback(async () => {
    const view = editor.current; if (!view) return;
    const data = await extractCodeData(fct);
    const deadCode = await Server.send(getDeadCode, fct);
    const code = buildExtension(data, CodeDecorationPlugin);
    const dead = buildExtension({ deadCode, ...data }, DeadCodePlugin);
    const extensions = baseExtensions.concat([code, dead]);
    const state = EditorState.create({ doc: data.code, extensions });
    printed.current = fct;
    view.setState(state);
  }, [editor, fct, baseExtensions]);

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
