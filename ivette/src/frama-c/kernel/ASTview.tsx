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

import React from 'react';
import Lodash from 'lodash';

import * as Dome from 'dome';
import * as Editor from 'dome/text/editor';
import * as Utils from 'dome/data/arrays';
import * as States from 'frama-c/states';
import * as Settings from 'dome/data/settings';
import { IconButton } from 'dome/controls/buttons';
import * as Ast from 'frama-c/kernel/api/ast';
import { text } from 'frama-c/kernel/api/data';
import * as Eva from 'frama-c/plugins/eva/api/general';
import * as Properties from 'frama-c/kernel/api/properties';
import * as Locations from './Locations';

import { TitleBar } from 'ivette';
import * as Preferences from 'ivette/prefs';

// -----------------------------------------------------------------------------
//  Utilitary types and functions
// -----------------------------------------------------------------------------

// An alias type for functions and locations.
type Decl = Ast.decl | undefined;
type Marker = Ast.marker | undefined;

// A range is just a pair of position in the code.
type Range = Editor.Range;

// Type checking that an input is defined.
function isDef<A>(a: A | undefined): a is A { return a !== undefined; }

// Map a function over a list, removing all inputs that returned undefined.
function mapFilter<A, B>(xs: readonly A[], fn: (x: A) => B | undefined): B[] {
  return xs.map(fn).filter(isDef);
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Tree datatype definition and utiliary functions
// -----------------------------------------------------------------------------

// The code is given by the server has a tree but implemented with arrays and
// without information on the ranges of each element. It will be converted in a
// good old tree that carry those information.
interface Leaf extends Range { text: string }
interface Node extends Range { marker: Ast.marker, children: Tree[] }
type Tree = Leaf | Node;

// Utility functions on trees.
function isLeaf(t: Tree): t is Leaf { return 'text' in t; }
function isNode(t: Tree): t is Node { return 'marker' in t && 'children' in t; }
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
    return [{ marker: Ast.jMarker(t[0]), from, to: acc, children }, acc];
  }
  const [res] = aux(t, 0);
  return res;
}

// Convert an Ivette text to defined Tree.
function rootText(t: text): Tree { return textToTree(t) ?? empty; }

// Convert an Ivette text into a string to be displayed.
function textToString(text: text): string {
  if (Array.isArray(text)) return text.slice(1).map(textToString).join('');
  else if (typeof text === 'string') return text;
  else return '';
}

// Computes, for each markers of a tree, its range. Returns the map containing
// all those bindings.
function markersRanges(tree: Tree): Map<string, Range[]> {
  const ranges: Map<string, Range[]> = new Map();
  const toRanges = (tree: Tree): void => {
    if (!isNode(tree)) return;
    const trees = ranges.get(tree.marker) ?? [];
    trees.push(tree);
    ranges.set(tree.marker, trees);
    for (const child of tree.children) toRanges(child);
  };
  toRanges(tree);
  return ranges;
}

function uniqueRange(m: string, rs: Map<string, Range[]>): Range | undefined {
  const ranges = rs.get(m);
  return (ranges && ranges.length > 0) ? ranges[0] : undefined;
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



// -----------------------------------------------------------------------------
//  Function code representation
// -----------------------------------------------------------------------------

// This field contains the current function's code as represented by Ivette.
// Its set function takes care to update the CodeMirror displayed document.
const Text = Editor.createTextField<text>(null, textToString);

// This aspect computes the tree representing the currently displayed function's
// code, represented by the <Text> field.
const Tree = Editor.createAspect({ t: Text }, ({ t }) => rootText(t));

// This aspect computes the markers ranges of the currently displayed function's
// tree, represented by the <Tree> aspect.
const Ranges = Editor.createAspect({ t: Tree }, ({ t }) => markersRanges(t));

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Selected marker representation
// -----------------------------------------------------------------------------

// This field contains the currently selected marker.
const Marker = Editor.createField<Marker>(undefined);

// This field contains the current multiple selection.
const Multiple = Editor.createField<Marker[]>([]);

// The marker field is considered as the ground truth on what is selected in the
// CodeMirror document. To do so, we catch the mouseup event (so when the user
// select a new part of the document) and update the Ivette selection
// accordingly. This will update the Marker field during the next Editor
// component's render and thus update everything else.
const MarkerUpdater = createMarkerUpdater();
function createMarkerUpdater(): Editor.Extension {
  const deps = { tree: Tree };
  return Editor.createEventHandler(deps, {
    mouseup: ({ tree }, view, event) => {
      const main = view.state.selection.main;
      const marker = coveringNode(tree, main.from)?.marker;
      States.setMarked(marker, event.altKey);
    }
  });
}

// A View updater that scrolls the selected marker into view. It is needed to
// handle Marker's updates from the outside world, as they do not change the
// cursor position inside CodeMirror.
const MarkerScroller = createMarkerScroller();
function createMarkerScroller(): Editor.Extension {
  const deps = { marker: Marker, ranges: Ranges };
  return Editor.createViewUpdater(deps, ({ marker, ranges }, view) => {
    if (!view || !marker) return;
    const markerRanges = ranges.get(marker) ?? [];
    if (markerRanges.length !== 1) return;
    const { from: anchor } = markerRanges[0];
    const line = view.state.doc.lineAt(anchor).number;
    Editor.selectLine(view, line, false, false);
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Hovered marker representation
// -----------------------------------------------------------------------------

// This field contains the currently hovered marker.
const Hovered = Editor.createField<Marker>(undefined);

// The Hovered field is updated each time the mouse moves through the CodeMirror
// document. The handlers updates the Ivette hovered information, which is then
// reflected on the Hovered field by the Editor component itself.
const HoveredUpdater = createHoveredUpdater();
function createHoveredUpdater(): Editor.Extension {
  const deps = { tree: Tree };
  return Editor.createEventHandler(deps, {
    mousemove: (inputs, view, event) => {
      const { tree } = inputs;
      const coords = { x: event.clientX, y: event.clientY };
      const pos = view.posAtCoords(coords);
      if (!pos) { States.setHovered(); return; }
      const node = coveringNode(tree, pos);
      if (!node) { States.setHovered(); return; }
      const from = view.coordsAtPos(node.from);
      if (!from) { States.setHovered(); return; }
      const to = view.coordsAtPos(node.to);
      if (!to) { States.setHovered(); return; }
      const left = Math.min(from.left, to.left);
      const right = Math.max(from.left, to.left);
      const top = Math.min(from.top, to.top);
      const bottom = Math.max(from.bottom, to.bottom);
      const horizontallyOk = left <= coords.x && coords.x <= right;
      const verticallyOk = top <= coords.y && coords.y <= bottom;
      if (!horizontallyOk || !verticallyOk) { States.setHovered(); return; }
      States.setHovered(node.marker);
    }
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Plugin decorating hovered and selected elements
// -----------------------------------------------------------------------------

const HoveredDecorator = createHoveredDecorator();
function createHoveredDecorator(): Editor.Extension {
  const cls = Editor.Decoration.mark({ class: 'cm-hovered-code' });
  const deps = { ranges: Ranges, hovered: Hovered };
  const extension = Editor.createDecorator(deps, ({ ranges, hovered }) => {
    const hoveredRanges = hovered ? (ranges.get(hovered) ?? []) : [];
    return Editor.RangeSet.of(hoveredRanges.map(r => cls.range(r.from, r.to)));
  });
  return Editor.setPriority(extension, 'highest');
}

const MarkerDecorator = createMarkerDecorator();
function createMarkerDecorator(): Editor.Extension {
  const cls = Editor.Decoration.mark({ class: 'cm-selected-code' });
  const deps = { ranges: Ranges, marker: Marker };
  const extension = Editor.createDecorator(deps, ({ ranges, marker }) => {
    const selectedRanges = marker ? (ranges.get(marker) ?? []) : [];
    return Editor.RangeSet.of(selectedRanges.map(r => cls.range(r.from, r.to)));
  });
  return Editor.setPriority(extension, 'high');
}

const MultipleDecorator = createMultipleDecorator();
function createMultipleDecorator(): Editor.Extension {
  const cls = Editor.Decoration.mark({ class: 'cm-multiple-code' });
  const deps = { ranges: Ranges, multiple: Multiple };
  const extension = Editor.createDecorator(deps, ({ ranges, multiple: ms }) => {
    const multRanges = mapFilter(ms.filter(isDef), (m) => ranges.get(m)).flat();
    return Editor.RangeSet.of(multRanges.map(r => cls.range(r.from, r.to)));
  });
  return Editor.setPriority(extension, 'default');
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Dead code decorations plugin
// -----------------------------------------------------------------------------

// This field contains the dead code information as inferred by Eva.
const emptyDeadCode = { reached: [], unreachable: [], nonTerminating: [] };
const Dead = Editor.createField<Eva.deadCode>(emptyDeadCode);

// Comparison function on ranges
function compareRange(x: Range, y: Range): number {
  return (x.from !== y.from) ? (x.from - y.from) : (y.to - x.to);
}

// The unreachable statements given by the server may contain reachable
// statements. This function is used to filter those reached statements.
function filterReached(unreachables: Range[], reachables: Range[]): Range[] {
  /* Sort [reachables] to always find the first largest reachable statement
     within an unreachable one (if any). */
  reachables.sort(compareRange);
  function keepTrulyUnreached(unreached: Range): Range[] {
    const reached = reachables.find((r) => Editor.startInto(r, unreached));
    if (reached === undefined) return [unreached];
    const firstUnreached = { from: unreached.from, to: reached.from - 1 };
    const next = { from: reached.to + 1, to: unreached.to };
    const result = (reached.to < unreached.to) ? keepTrulyUnreached(next) : [];
    if (unreached.from < reached.from) result.unshift(firstUnreached);
    return result;
  }
  return unreachables.map(keepTrulyUnreached).flat();
}

const UnreachableRanges = createUnreachableRanges();
function createUnreachableRanges(): Editor.Aspect<Editor.Range[]> {
  const deps = { dead: Dead, ranges: Ranges };
  return Editor.createAspect(deps, ({ dead, ranges }) => {
    const unreachable = mapFilter(dead.unreachable, m => ranges.get(m)).flat();
    const reached = mapFilter(dead.reached, m => ranges.get(m)).flat();
    return filterReached(unreachable, reached);
  });
}

const NonTerminatingRanges = createNonTerminatingRanges();
function createNonTerminatingRanges(): Editor.Aspect<Editor.Range[]> {
  const deps = { dead: Dead, ranges: Ranges };
  return Editor.createAspect(deps, ({ dead, ranges }) => {
    return mapFilter(dead.nonTerminating, m => ranges.get(m)).flat();
  });
}

const DeadCodeDecorator = createDeadCodeDecorator();
function createDeadCodeDecorator(): Editor.Extension {
  const uCls = Editor.Decoration.mark({ class: 'cm-dead-code' });
  const tCls = Editor.Decoration.mark({ class: 'cm-non-term-code' });
  const deps = { unreach: UnreachableRanges, nonTerm: NonTerminatingRanges };
  return Editor.createDecorator(deps, ({ unreach, nonTerm }) => {
    const unreachable = unreach.map(r => uCls.range(r.from, r.to));
    const nonTerminating = nonTerm.map(r => tCls.range(r.from, r.to));
    return Editor.RangeSet.of(unreachable.concat(nonTerminating), true);
  });
}

type DeadCodeKind = 'unreachable' | 'non terminating';
class DeadCodeGutterMarker extends Editor.GutterMarker {
  readonly element: HTMLDivElement;
  toDOM(): HTMLDivElement { return this.element; }
  constructor(kind: DeadCodeKind) {
    super();
    const color = kind === 'unreachable' ? 'dead-code' : 'non-terminating';
    this.element = document.createElement('div');
    this.element.innerHTML = 'a';
    this.element.title = `This code is ${kind}`;
    this.element.style.width = '4px';
    this.element.style.color = `var(--${color})`;
    this.element.style.borderRight = `4px solid var(--${color})`;
  }
}

const DeadCodeGutter = createDeadCodeGutter();
function createDeadCodeGutter(): Editor.Extension {
  const deps = { unreach: UnreachableRanges, nonTerm: NonTerminatingRanges };
  const cls = 'cm-deadcode-gutter';
  return Editor.createGutter(deps, cls, (props, block, view) => {
    const doc = view.state.doc;
    const line = doc.lineAt(block.from);
    const unreachable = props.unreach
      .filter(r => r.from <= doc.length)
      .map(r => ({ from: doc.lineAt(r.from).from, to: doc.lineAt(r.to).to }))
      .find(r => r.from <= line.from && line.to <= r.to);
    if (unreachable) return new DeadCodeGutterMarker('unreachable');
    const nonTerm = props.nonTerm
      .filter(r => r.from <= doc.length)
      .map(r => ({ from: doc.lineAt(r.from).from, to: doc.lineAt(r.to).to }))
      .find(r => r.from <= line.from && line.to <= r.to);
    if (nonTerm) return new DeadCodeGutterMarker('non terminating');
    return null;
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Property bullets extension
// -----------------------------------------------------------------------------

// This field contains information on properties' tags.
type Tags = Map<string, States.Tag>;
const Tags = Editor.createField<Tags>(new Map());

// The component needs information on markers' status data.
const PropertiesStatuses = Editor.createField<Properties.statusData[]>([]);

// Recovers all the properties nodes in a tree.
function getPropertiesNodes(tree: Tree): Node[] {
  if (isLeaf(tree)) return [];
  /* Must be consistent with the id chosen by the Frama-C server for property
     markers. Ideally, this test should not depend on markers id syntax. */
  if (tree.marker.startsWith('#p')) return [tree];
  return tree.children.map(getPropertiesNodes).flat();
}

// This aspect contains all the properties nodes, along with their tags.
interface Property extends Node { tag: States.Tag }
const PropertiesNodes = createPropertiesNodes();
function createPropertiesNodes() : Editor.Aspect<Property[]> {
  const deps = { tree: Tree, tags: Tags, statuses: PropertiesStatuses };
  return Editor.createAspect(deps, ({ tree, tags, statuses }) => {
    const nodes = getPropertiesNodes(tree);
    return mapFilter(nodes, (n) => {
      const s = statuses.find((s) => s.key === n.marker);
      if (!s) return undefined;
      const tag = tags.get(s.status);
      if (!tag) return undefined;
      return { ...n, tag };
    });
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
class PropertyBullet extends Editor.GutterMarker {
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
function createPropertiesGutter(): Editor.Extension {
  const deps = { properties: PropertiesNodes };
  const cls = 'cm-property-gutter';
  return Editor.createGutter(deps, cls, (inputs, block, view) => {
    const { properties } = inputs;
    const doc = view.state.doc;
    // Should not be needed, but we can't properly handle dependencies for
    // gutters, so sometimes the property nodes do not match the document.
    const valids = properties.filter((p) => p.from <= doc.length);
    const line = doc.lineAt(block.from);
    const prop = valids.find((p) => line.from === doc.lineAt(p.from).from);
    const res = prop ? new PropertyBullet(prop.tag) : null;
    return res;
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Context menu
// -----------------------------------------------------------------------------

type MarkerMenuExtender =
  (items: Dome.PopupMenuItem[], attr: Ast.markerAttributesData) => void;

const MarkerMenuExtenders : MarkerMenuExtender[] = [];

export function registerMarkerMenuExtender(e : MarkerMenuExtender) : void {
  MarkerMenuExtenders.push(e);
}

// This field contains all the current function's callers, as inferred by Eva.
const Callers = Editor.createField<Eva.CallSite[]>([]);

// This field contains the function pointed to by the current hovered marker,
// as inferred by Eva.
const Callees = Editor.createField<Ast.decl[]>([]);

const ContextMenuHandler = createContextMenuHandler();
function createContextMenuHandler(): Editor.Extension {
  const deps = {
    tree: Tree,
    callers: Callers,
    callees: Callees,
  };
  return Editor.createEventHandler(deps, {
    contextmenu: (inputs, view, event) => {
      const { tree, callers, callees } = inputs;
      const coords = { x: event.clientX, y: event.clientY };
      const position = view.posAtCoords(coords); if (!position) return;
      const node = coveringNode(tree, position);
      if (!node || !node.marker) return;
      const items: Dome.PopupMenuItem[] = [];
      const attributes = States.getMarker(node.marker);
      const { kind, labelKind, name, definition } = attributes;
      if (kind === 'DFUN') {
        const groupedCallers = Lodash.groupBy(callers, ({ call }) => call);
        const markers = callers.map(({ stmt }) => stmt);
        const descr = `Calls to ${name}`;
        Lodash.forEach(groupedCallers, (group) => {
          const n = group.length;
          const { call } : Eva.CallSite = group[0];
          const { name: fct } = States.getDeclaration(call);
          const caller = `caller ${fct}`;
          const nsites = n > 1 ? `s (${n} call sites)` : '';
          const label = `Go to ${caller}${nsites}`;
          const index = callers.findIndex(({ call: f }) => f === call);
          const onClick = (): void => Locations.setSelection({
            label: descr, markers, index, plugin: 'Callers',
          });
          items.push({ label, onClick });
        });
      } else if (definition) {
        const label = `Go to ${name} (${labelKind.toLowerCase()})`;
        const onClick = (): void => States.setSelected(definition);
        items.push({ label, onClick });
      } else if (callees.length > 0) {
        callees.forEach((decl) => {
          const { name: fct } = States.getDeclaration(decl);
          const onClick = (): void => States.setCurrentScope(decl);
          const label = `Go to ${fct} (indirect call)`;
          items.push({ label, onClick });
        });
      }
      MarkerMenuExtenders.forEach((ext) => ext(items, attributes));
      items.push({
        label: 'Copy to clipboard',
        onClick: () => {
          const text = view.state.sliceDoc(node.from, node.to);
          if (text !== '') navigator.clipboard.writeText(text);
      } });
      Dome.popupMenu(items);
      return;
    }
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Tainted lvalues
// -----------------------------------------------------------------------------

type Taints = Eva.LvalueTaints;
const TaintedLvalues = Editor.createField<Taints[] | undefined>(undefined);

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
function createTaintedLvaluesDecorator(): Editor.Extension {
  const mark = Editor.Decoration.mark({ class: 'cm-tainted' });
  const deps = { ranges: Ranges, tainted: TaintedLvalues };
  return Editor.createDecorator(deps, ({ ranges, tainted = [] }) => {
    const find = (t: Taints): Range[] | undefined => ranges.get(t.lval);
    const taintedRanges = mapFilter(tainted, find).flat();
    const marks = taintedRanges.map(r => mark.range(r.from, r.to));
    return Editor.RangeSet.of(marks, true);
  });
}

const TaintTooltip = createTaintTooltip();
function createTaintTooltip(): Editor.Extension {
  const deps = { hovered: Hovered, ranges: Ranges, tainted: TaintedLvalues };
  return Editor.createTooltip(deps, ({ hovered, ranges, tainted }) => {
    const hoveredTaint = tainted?.find(t => t.lval === hovered);
    const hoveredNode = hovered && uniqueRange(hovered, ranges);
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



// -----------------------------------------------------------------------------
//  Server requests
// -----------------------------------------------------------------------------

// Server request handler returning the given function's text.
function useAST(decl: Ast.decl | undefined): text {
  return States.useRequest(
    Ast.printDeclaration, decl || undefined,
    { onError: [] }
  ) ?? [];
}

// Server request handler returning the given function's callers.
function useCallers(decl: Decl): Eva.CallSite[] {
  return States.useRequest(
    Eva.getCallers, decl || undefined,
    { onError: [] }
  ) ?? [];
}

// Server request handler returning the given function's callers.
function useCallees(marker: Marker): Ast.decl[] {
  return States.useRequest(
    Eva.getCallees, marker || undefined,
    { onError: [] }
  ) ?? [];
}

// Server request handler returning the tainted lvalues.
function useTaints(decl: Decl): Eva.LvalueTaints[] {
  return States.useRequest(Eva.taintedLvalues, decl, { onError: [] }) ?? [];
}

// Server request handler returning the given function's dead code information.
function useDead(decl: Decl): Eva.deadCode {
  return States.useRequest(
    Eva.getDeadCode, decl || undefined,
    { onError: emptyDeadCode }
  ) ?? emptyDeadCode;
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  AST View component
// -----------------------------------------------------------------------------

// Necessary extensions for our needs.
const extensions: Editor.Extension[] = [
  MarkerUpdater,
  MarkerScroller,
  HoveredUpdater,
  HoveredDecorator,
  MarkerDecorator,
  MultipleDecorator,
  DeadCodeDecorator,
  ContextMenuHandler,
  PropertiesGutter,
  DeadCodeGutter,
  TaintedLvaluesDecorator,
  TaintTooltip,
  Editor.ReadOnly,
  Editor.FoldGutter,
  Editor.LanguageHighlighter,
];

// The component in itself.
export default function ASTview(): JSX.Element {
  const [fontSize] = Settings.useGlobalSettings(Preferences.EditorFontSize);
  const { view, Component } = Editor.Editor(extensions);

  // Current selection
  const { scope, marker = Ast.markerDefault } = States.useCurrentLocation();
  React.useEffect(() => Marker.set(view, marker), [view, marker]);
  const hovered = States.useHovered() ?? Ast.markerDefault;
  React.useEffect(() => Hovered.set(view, hovered), [view, hovered]);

  // State unFoldButton
  const [isFoldText, setIsFoldText] = React.useState(false);
  const icon = 'CHEVRON.' + (isFoldText ? 'EXPAND' : 'CONTRACT');
  const title = isFoldText ? 'Expand' : 'Collapse';
  const unFoldButtonClicked = (): void => { setIsFoldText(!isFoldText); };

  // Multiple selection
  const { markers } = Locations.useSelection();
  React.useEffect(() => Multiple.set(view, markers), [view, markers]);

  // Property status
  const props = States.useSyncArrayData(Properties.status);
  React.useEffect(() => PropertiesStatuses.set(view, props), [view, props]);

  // Property tags
  const tags = States.useTags(Properties.propStatusTags);
  React.useEffect(() => Tags.set(view, tags), [view, tags]);

  // Printed AST
  const text = useAST(scope);
  React.useEffect(() => Text.set(view, text), [view, text]);
  React.useEffect(() => {
    isFoldText ? Editor.foldAll(view) : Editor.unfoldAll(view);
  }, [view, isFoldText, text]);

  // EVA Callbacks
  const dead = useDead(scope);
  React.useEffect(() => Dead.set(view, dead), [view, dead]);
  const callers = useCallers(scope);
  React.useEffect(() => Callers.set(view, callers), [view, callers]);
  const callees = useCallees(hovered);
  React.useEffect(() => Callees.set(view, callees), [view, callees]);
  const taints = useTaints(scope);
  React.useEffect(() => TaintedLvalues.set(view, taints), [view, taints]);

  return (
    <>
      <TitleBar>
        <IconButton
          icon={icon}
          onClick= {unFoldButtonClicked}
          title={title + ' all multi-line ACSL properties'}
          className="titlebar-thin-icon"
        />
      </TitleBar>
      <Component style={{ fontSize: `${fontSize}px` }} />
    </>
  );
}

// -----------------------------------------------------------------------------
