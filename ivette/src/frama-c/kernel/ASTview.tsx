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

import React from 'react';
import Lodash from 'lodash';

import * as Dome from 'dome';
import * as Editor from 'dome/text/editor';
import * as Utils from 'dome/data/arrays';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import { key } from 'dome/data/json';
import * as Settings from 'dome/data/settings';
import { IconButton } from 'dome/controls/buttons';
import { Filler, Inset } from 'dome/frame/toolbars';
import * as Ast from 'frama-c/kernel/api/ast';
import { text } from 'frama-c/kernel/api/data';
import * as Eva from 'frama-c/plugins/eva/api/general';
import * as Properties from 'frama-c/kernel/api/properties';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';

import { TitleBar } from 'ivette';
import * as Preferences from 'ivette/prefs';



// -----------------------------------------------------------------------------
//  Utilitary types and functions
// -----------------------------------------------------------------------------

// An alias type for functions and locations.
type Fct = string | undefined;
type Marker = string | undefined;

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
function markersRanges(tree: Tree): Map<string, Range[]>{
  const ranges: Map<string, Range[]> = new Map();
  const toRanges = (tree: Tree): void => {
    if (!isNode(tree)) return;
    const trees = ranges.get(tree.id) ?? [];
    trees.push(tree);
    ranges.set(tree.id, trees);
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
const Tree = Editor.createAspect({ t: Text }, ({t}) => textToTree(t) ?? empty);

// This aspect computes the markers ranges of the currently displayed function's
// tree, represented by the <Tree> aspect.
const Ranges = Editor.createAspect({ t: Tree }, ({ t }) => markersRanges(t));

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Selected marker representation
// -----------------------------------------------------------------------------

// This field contains the currently selected function.
const Fct = Editor.createField<Fct>(undefined);

// This field contains the currently selected marker.
const Marker = Editor.createField<Marker>(undefined);

// This field contains the current multiple selection.
const Multiple = Editor.createField<Marker[]>([]);

// The Ivette selection must be updated by CodeMirror plugins. This input
// add the callback in the CodeMirror internal state.
type UpdateSelection = (a: States.SelectionActions) => void;
const UpdateSelection = Editor.createField<UpdateSelection>(() => { return; });

// The marker field is considered as the ground truth on what is selected in the
// CodeMirror document. To do so, we catch the mouseup event (so when the user
// select a new part of the document) and update the Ivette selection
// accordingly. This will update the Marker field during the next Editor
// component's render and thus update everything else.
const MarkerUpdater = createMarkerUpdater();
function createMarkerUpdater(): Editor.Extension {
  const deps = { fct: Fct, tree: Tree, update: UpdateSelection };
  return Editor.createEventHandler(deps, {
    mouseup: ({ fct, tree, update }, view, event) => {
      const main = view.state.selection.main;
      const id = coveringNode(tree, main.from)?.id;
      const location = { fct, marker: Ast.jMarker(id) };
      update({ location });
      if (event.altKey) States.MetaSelection.emit(location);
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
    view.dispatch({ selection: { anchor }, scrollIntoView: true });
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Hovered marker representation
// -----------------------------------------------------------------------------

// This field contains the currently hovered marker.
const Hovered = Editor.createField<Marker>(undefined);

// The Ivette hovered element must be updated by CodeMirror plugins. This
// field add the callback in the CodeMirror internal state.
type UpdateHovered = (h: States.Hovered) => void;
const UpdateHovered = Editor.createField<UpdateHovered>(() => { return ; });

// The Hovered field is updated each time the mouse moves through the CodeMirror
// document. The handlers updates the Ivette hovered information, which is then
// reflected on the Hovered field by the Editor component itself.
const HoveredUpdater = createHoveredUpdater();
function createHoveredUpdater(): Editor.Extension {
  const deps = { fct: Fct, tree: Tree, update: UpdateHovered };
  return Editor.createEventHandler(deps, {
    mousemove: (inputs, view, event) => {
      const { fct, tree, update: updateHovered } = inputs;
      const coords = { x: event.clientX, y: event.clientY };
      const reset = (): void => updateHovered(undefined);
      const pos = view.posAtCoords(coords);
      if (!pos) { reset(); return; }
      const hov = coveringNode(tree, pos);
      if (!hov) { reset(); return; }
      const from = view.coordsAtPos(hov.from);
      if (!from) { reset(); return; }
      const to = view.coordsAtPos(hov.to);
      if (!to) { reset(); return; }
      const left = Math.min(from.left, to.left);
      const right = Math.max(from.left, to.left);
      const top = Math.min(from.top, to.top);
      const bottom = Math.max(from.bottom, to.bottom);
      const horizontallyOk = left <= coords.x && coords.x <= right;
      const verticallyOk = top <= coords.y && coords.y <= bottom;
      if (!horizontallyOk || !verticallyOk) { reset(); return; }
      const marker = Ast.jMarker(hov.id);
      updateHovered(marker ? { fct, marker } : undefined);
    }
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Plugin decorating hovered and selected elements
// -----------------------------------------------------------------------------

const CodeDecorator = createCodeDecorator();
function createCodeDecorator(): Editor.Extension {
  const hoveredClass = Editor.Decoration.mark({ class: 'cm-hovered-code' });
  const selectedClass = Editor.Decoration.mark({ class: 'cm-selected-code' });
  const multipleClass = Editor.Decoration.mark({ class: 'cm-multiple-code' });
  const selections = { marker: Marker, multiple: Multiple, hovered: Hovered };
  const deps = { ranges: Ranges, ...selections };
  return Editor.createDecorator(deps, (props) => {
    const { ranges, marker: m, hovered: h, multiple: ms } = props;
    const multRanges = mapFilter(ms.filter(isDef), (m) => ranges.get(m)).flat();
    const hoveredRanges = h ? (ranges.get(h) ?? []) : [];
    const selectedRanges = m ? (ranges.get(m) ?? []) : [];
    const hovered  = hoveredRanges.map(r =>  hoveredClass.range(r.from, r.to));
    const selected = selectedRanges.map(r => selectedClass.range(r.from, r.to));
    const multiple = multRanges.map(r => multipleClass.range(r.from, r.to));
    const decorations = selected.concat(hovered, multiple);
    return Editor.RangeSet.of(decorations, true);
  });
}

// -----------------------------------------------------------------------------



// -----------------------------------------------------------------------------
//  Dead code decorations plugin
// -----------------------------------------------------------------------------

// This field contains the dead code information as inferred by Eva.
const emptyDeadCode = { unreachable: [], nonTerminating: [] };
const Dead = Editor.createField<Eva.deadCode>(emptyDeadCode);

const DeadCodeDecorator = createDeadCodeDecorator();
function createDeadCodeDecorator(): Editor.Extension {
  const uClass = Editor.Decoration.mark({ class: 'cm-dead-code' });
  const tClass = Editor.Decoration.mark({ class: 'cm-non-term-code' });
  const deps = { dead: Dead, ranges: Ranges };
  return Editor.createDecorator(deps, ({ dead, ranges }) => {
    const range = (m: string): Range[] | undefined => ranges.get(m);
    const unreachableRanges = mapFilter(dead.unreachable, range).flat();
    const unreachable = unreachableRanges.map(r => uClass.range(r.from, r.to));
    const nonTermRanges = mapFilter(dead.nonTerminating, range).flat();
    const nonTerm = nonTermRanges.map(r => tClass.range(r.from, r.to));
    return Editor.RangeSet.of(unreachable.concat(nonTerm), true);
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
  if (tree.id.startsWith('#p')) return [tree];
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
      const s = statuses.find((s) => s.key === n.id);
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



// -----------------------------------------------------------------------------
//  Context menu
// -----------------------------------------------------------------------------

// This field contains all the current function's callers, as inferred by Eva.
const Callers = Editor.createField<Eva.CallSite[]>([]);

// This field contains information on markers.
type GetMarkerData = (key: string) => Ast.markerInfoData | undefined;
const GetMarkerData = Editor.createField<GetMarkerData>(() => undefined);

const ContextMenuHandler = createContextMenuHandler();
function createContextMenuHandler(): Editor.Extension {
  const data = { tree: Tree, callers: Callers };
  const deps = { ...data, update: UpdateSelection, getData: GetMarkerData };
  return Editor.createEventHandler(deps, {
    contextmenu: (inputs, view, event) => {
      const { tree, callers, update, getData } = inputs;
      const coords = { x: event.clientX, y: event.clientY };
      const position = view.posAtCoords(coords); if (!position) return;
      const node = coveringNode(tree, position);
      if (!node || !node.id) return;
      const items: Dome.PopupMenuItem[] = [];
      const info = getData(node.id);
      if (info?.var === 'function') {
        if (info.kind === 'declaration') {
          const groupedCallers = Lodash.groupBy(callers, e => e.kf);
          const locations = callers.map((l) => ({ fct: l.kf, marker: l.stmt }));
          Lodash.forEach(groupedCallers, (e) => {
            const callerName = e[0].kf;
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
function useFctText(fct: Fct): text {
  return States.useRequest(Ast.printFunction, fct) ?? null;
}

// Server request handler returning the given function's dead code information.
function useFctDead(fct: Fct): Eva.deadCode {
  const empty = { unreachable: [], nonTerminating: [] };
  return States.useRequest(Eva.getDeadCode, fct) ?? empty;
}

// Server request handler returning the given function's callers.
function useFctCallers(fct: Fct): Eva.CallSite[] {
  return States.useRequest(Eva.getCallers, fct) ?? [];
}

// Server request handler returning the tainted lvalues.
function useFctTaints(fct: Fct): Eva.LvalueTaints[] {
  return States.useRequest(Eva.taintedLvalues, fct, { onError: [] }) ?? [];
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
  CodeDecorator,
  DeadCodeDecorator,
  ContextMenuHandler,
  PropertiesGutter,
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

  // Updating CodeMirror when the selection or its callback are changed.
  const [selection, setSel] = States.useSelection();
  React.useEffect(() => UpdateSelection.set(view, setSel), [view, setSel]);
  const fct = selection?.current?.fct;
  React.useEffect(() => Fct.set(view, fct), [view, fct]);
  const marker = selection?.current?.marker;
  React.useEffect(() => Marker.set(view, marker), [view, marker]);
  const multiple = selection?.multiple.allSelections.map(l => l.marker);
  React.useEffect(() => Multiple.set(view, multiple), [view, multiple]);

  // Updating CodeMirror when the <updateHovered> callback is changed.
  const [hov, setHov] = States.useHovered();
  React.useEffect(() => UpdateHovered.set(view, setHov), [view, setHov]);
  React.useEffect(() => Hovered.set(view, hov?.marker ?? ''), [view, hov]);

  // Updating CodeMirror when the <properties> synchronized array is changed.
  const props = States.useSyncArray(Properties.status).getArray();
  React.useEffect(() => PropertiesStatuses.set(view, props), [view, props]);

  // Updating CodeMirror when the <propStatusTags> map is changed.
  const tags = States.useTags(Properties.propStatusTags);
  React.useEffect(() => Tags.set(view, tags), [view, tags]);

  // Updating CodeMirror when the <markersInfo> synchronized array is changed.
  const info = States.useSyncArray(Ast.markerInfo);
  const getData = React.useCallback((key) => info.getData(key), [info]);
  React.useEffect(() => GetMarkerData.set(view, getData), [view, getData]);

  // Retrieving data on currently selected function and updating CodeMirror when
  // they have changed.
  const text = useFctText(fct);
  React.useEffect(() => Text.set(view, text), [view, text]);
  const dead = useFctDead(fct);
  React.useEffect(() => Dead.set(view, dead), [view, dead]);
  const callers = useFctCallers(fct);
  React.useEffect(() => Callers.set(view, callers), [view, callers]);
  const taints = useFctTaints(fct);
  React.useEffect(() => TaintedLvalues.set(view, taints), [view, taints]);

  return (
    <>
      <TitleBar>
        <Filler />
        <IconButton
          icon='CHEVRON.CONTRACT'
          visible={true}
          onClick={() => Editor.foldAll(view)}
          title='Collapse all multi-line ACSL properties'
          className="titlebar-thin-icon"
        />
        <IconButton
          icon='CHEVRON.EXPAND'
          visible={true}
          onClick={() => Editor.unfoldAll(view)}
          title='Expand all multi-line ACSL properties'
          className="titlebar-thin-icon"
        />
        <Inset />
      </TitleBar>
      <Component style={{ fontSize: `${fontSize}px`}} />
    </>
  );
}

// -----------------------------------------------------------------------------
