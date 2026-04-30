/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

import { useFlipSettings, popupMenu } from 'dome';
import { Dropdown } from 'dome/dialogs';
import * as Tree from 'dome/frame/tree';
import * as Toolbars from 'dome/frame/toolbars';
import * as Buttons from 'dome/controls/buttons';
import { useGlobalState } from 'dome/data/states';
import { makeBadge } from 'dome/frame/sidebars';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as EvaAnalysis from 'frama-c/plugins/eva/api/analysis';
import * as Ast from 'frama-c/kernel/api/ast';
import { getDeclaration } from 'frama-c/states';
import { menuItem } from 'frama-c/kernel/Globals';

import * as Eva from './api/callstack';
import { EvaReady } from './components/AnalysisStatus';
import { CallstackState } from './valuetable';

// ----------------------------------------------------------------------------

interface Info extends Eva.callstackInfo { callstack: Eva.callstack}

interface Node {
  key: string;
  label: string;
  decl: Ast.decl;
  callstack: Info;
  parentKey?: string;
  subTree: NodesMap;
}

type NodesMap = Map<string, Node>;


// ----------------------------------------------------------------------------
// --- CallstackSelection message
// ----------------------------------------------------------------------------

const pinnedMessageId = 'EvaFilterCallstack';

function addMessage(count: number, remove: () => void): void {
  const pinnedMessageButton =
    <Buttons.IconButton
      icon='TRASH'
      title='Clear callstack selection: show all callstacks'
      onClick={remove}
    />;
  const pinnedMessage: Toolbars.PinnedMessage = {
    id: pinnedMessageId,
    message:
      `Only ${count} callstack${count === 1 ? ' is' : 's are'} currently shown`,
    actions: pinnedMessageButton
  };
  Toolbars.addPinnedMessage(pinnedMessage);
}

function delMessage(): void {
  Toolbars.delPinnedMessage(pinnedMessageId);
}

// ----------------------------------------------------------------------------
// --- Component Nodes
// ----------------------------------------------------------------------------

function getActions(
  id: Eva.callstack,
  onClick: (id: Eva.callstack) => void,
  current?: Eva.callstack[]
): React.JSX.Element | null {
  const isSelected = current?.includes(id);
  return (
    <Buttons.Checkbox
      title={(isSelected ? 'Deselect' : 'Select') + ' the callstack'}
      value={isSelected}
      onChange={() => onClick(id)}
    />
  );
}

interface NodesProps {
  tree: NodesMap,
  visible?: Set<string>,
  onClick: (id: Eva.callstack) => void
}

function Nodes({ tree, visible, onClick } : NodesProps): React.ReactNode {
  const [current, ] = States.useSyncState(Eva.currentCallstacks);

  return [...tree].map(([, { key, label, callstack, subTree }]) => {
    const loc = States.getMarker(callstack.stack[0]?.stmt).sloc;
    const title = loc ? loc.base+': '+loc.line : '';
    return (
      <Tree.Node key={key} id={key} label={label} title={title}
        visible={visible?.has(key) ?? true}
        actions={getActions(callstack.callstack, onClick, current)}
      >
        { subTree && subTree.size > 0 ?
          <Nodes tree={subTree} visible={visible} onClick={onClick} />
          : null
        }
      </Tree.Node>
    );
  });
}

// ----------------------------------------------------------------------------
// --- Infos Nodes
// ----------------------------------------------------------------------------

function isEntryPoint(cs: Info): boolean { return cs.stack.length === 0; }

function compareStack(a: Eva.callsite[], b: Eva.callsite[]): boolean {
  if(a.length !== b.length) return false;
  return a.every((e, i) => (
    e.callee === b[i].callee
    && e.caller === b[i].caller
    && e.stmt === b[i].stmt
  ));
}

function getParentKey(cs: Info, callstacks: Info[]): string | undefined {
  if(isEntryPoint(cs)) return undefined;
  return callstacks.find(e => (
    e.thread === cs.thread
    && e.entryPoint === cs.entryPoint
    && compareStack(e.stack, cs.stack.slice(1))
  ))?.callstack.toString();
}

function getNode(key: string, cs: Info, callstacks: Info[]): Node {
  const decl = isEntryPoint(cs) ? cs.entryPoint : cs.stack[0].callee;
  const parentKey = getParentKey(cs, callstacks);
  const label = getDeclaration(decl).name;
  return {
    key, label, decl,
    callstack: cs,
    parentKey: parentKey,
    subTree: new Map()
  };
}

/** Return the Tree */
function getTree(callstacks: Info[]): {nodes: NodesMap, tree: NodesMap} {
  const nodes: NodesMap = new Map();
  const tree: NodesMap = new Map();

  // Create nodes and tree
  callstacks.forEach(cs => {
    const key = cs.callstack.toString();
    const newNode = getNode(key, cs, callstacks);
    nodes.set(key, newNode);
    // The tree contains only entry points
    if(isEntryPoint(newNode.callstack))
      tree.set(key, newNode);
  });

  // populate subTrees
  nodes.forEach(node => {
    if(node.parentKey) {
      const parent = nodes.get(node.parentKey);
      parent?.subTree.set(node.key, node);
    }
  });

  return { nodes, tree };
}

/** Get details of callstacks */
async function getInfosCallstacks(
  callstacks: Eva.callstack[],
  callback: (a: Info[]) => void
): Promise<void> {
  const infos = await Promise.all(callstacks.map(async (cs) => {
    const info = await Server.send(Eva.getCallstackInfo, cs);
    return { ...info, callstack: cs };
  }));
  callback(infos);
}

export function useCallstacks(): Info[] {
  const serverStatus = Server.useStatus();
  const evaStatus = States.useSyncValue(EvaAnalysis.computationState);

  const [callstacks, setCallstacks] = React.useState<Eva.callstack[]>([]);
  const [infos, setInfos] = React.useState<Info[]>([]);

  React.useEffect(() => {
    if(serverStatus === 'ON'
      && (evaStatus === 'computed' || evaStatus === 'aborted'))
      Server.send(Eva.getAllCallstacks, []).then(setCallstacks);
    else setCallstacks([]);
  }, [serverStatus, evaStatus]);

  React.useEffect(() => {
    getInfosCallstacks(callstacks, setInfos);
  }, [callstacks]);

  return infos;
}

export interface CallstackSelection {
  selection: Eva.callstack[],
  isSelected: (callstack: Eva.callstack) => boolean,
  flipSelected: (callstack: Eva.callstack) => void,
  reset: () => void
}

export function useCallstackSelection(): CallstackSelection {
  const [_selection, setSelection] = States.useSyncState(Eva.currentCallstacks);
  const selection = React.useMemo(() => _selection ?? [], [_selection]);

  const isSelected = React.useCallback((id: Eva.callstack): boolean => {
    return selection.length > 0 && selection.includes(id);
  }, [selection]);

  const flipSelected = React.useCallback((id: Eva.callstack): void => {
    if (isSelected(id))
      setSelection(selection.filter(e => e !== id));
    else
      setSelection([...selection, id]);
  }, [selection, isSelected, setSelection]);

  const reset = React.useCallback(() => setSelection([]), [setSelection]);

  /** update warning when selected change */
  React.useEffect(() => {
    if (selection.length > 0) addMessage(selection.length, reset);
    else delMessage();
  }, [selection, reset]);

  return { selection, isSelected, flipSelected, reset };
}

// ----------------------------------------------------------------------------
// --- Component CallstackSelection
// ----------------------------------------------------------------------------

/**
 * Calculates the visible nodes based on the filters,
 * then adds parent and child nodes (single level) if necessary.
 *
 * All unanalysed nodes are leaves, so parent nodes are not calculated if the
 * ‘showAnalyzed’ option is selected. Child nodes are only calculated if
 * neither ‘showAnalyzed’ nor ‘showUnanalyzed’ is selected.
 */
function getVisibleKey(
  nodes: NodesMap,
  showSelected: boolean,
  showScope: boolean,
  showAnalyzed: boolean,
  showUnanalyzed: boolean,
  selection: Eva.callstack[],
  scope: States.Scope
): Set<string> | undefined {
  // return ‘undefined’ to display all nodes
  if(showAnalyzed && showUnanalyzed) return undefined;

  const keys = new Set<string>();
  if(showScope && scope)
    [...nodes].filter(e => e[1].decl === scope).forEach(e => keys.add(e[0]));
  if(showSelected && selection.length > 0)
    selection.forEach(s => keys.add(s.toString()));
  if(showAnalyzed)
    [...nodes].filter(e => e[1].callstack.analyzed)
      .forEach(e => keys.add(e[0]));
  if(showUnanalyzed)
    [...nodes].filter(e => !(e[1].callstack.analyzed))
      .forEach(e => keys.add(e[0]));

  if(keys.size === 0) return new Set([]);

  /** Get all parents */
  const parentKeys = new Set<string>();
  function getParents(curr: string): void {
    const parentKey = nodes.get(curr)?.parentKey;
    if(!parentKey) return;
    parentKeys.add(parentKey);
    getParents(parentKey);
  }
  if(!showAnalyzed) [...keys].forEach(e => getParents(e));

  /** Get a single level of children */
  const childrenKeys = new Set<string>();
  function getAnalyzedChildren(curr: string): void {
    const node = nodes.get(curr);
    if(!node) return;
    const children = [...node.subTree.entries()];
    children.forEach(e => {
      if (e[1].callstack.analyzed) childrenKeys.add(e[0]);
    });
  }
  if(!showAnalyzed) [...keys].forEach(e => getAnalyzedChildren(e));

  return new Set([...keys, ...parentKeys, ...childrenKeys]);
}

export function CallstackSelection(): React.JSX.Element {
  // Control
  const [ unfold, setUnfold ] = React.useState<boolean|undefined>(false);
  const showSelectedState = useFlipSettings('callstack.show.selected', true);
  const [showSelected,] = showSelectedState;
  const showScopeState = useFlipSettings('callstack.show.scope', true);
  const [showScope,] = showScopeState;
  const showAnalyzedState = useFlipSettings('callstack.show.analyzed', false);
  const [showAnalyzed,] = showAnalyzedState;
  const showUnanalyzedState =
    useFlipSettings('callstack.show.unanalyzed', false);
  const [showUnanalyzed,] = showUnanalyzedState;
  // Data
  const infos = useCallstacks();
  const { selection, flipSelected, reset } = useCallstackSelection();
  const [selectedFromValue, ] = useGlobalState(CallstackState);
  const scope = States.useCurrentScope();

  /** Tree */
  const { nodes, tree } = React.useMemo(() => getTree(infos), [infos]);

  /** Filter */
  const filterItems: Buttons.MultiselectItemProps[] = [
    menuItem({ label: 'Show selected', state: showSelectedState }),
    menuItem({ label: 'Show scope', state: showScopeState }),
    menuItem({ label: 'Show analyzed', state: showAnalyzedState }),
    menuItem({ label: 'Show unanalyzed', state: showUnanalyzedState }),
  ];
  const itemsComp = filterItems.map(
    (e, i) => <Buttons.MultiselectItem key={i} item={e} />);

  /** List of keys for visible nodes */
  const visibleKeys = React.useMemo(() => {
    return getVisibleKey(nodes, showSelected, showScope,
      showAnalyzed, showUnanalyzed, selection, scope);
  }, [nodes, showSelected, showScope,
      showAnalyzed, showUnanalyzed, selection, scope]);


  const onResetMenu = React.useCallback(() => {
    popupMenu([
      { label: 'Reset selection: show all callstacks', onClick: () => reset() }
    ]);
  }, [reset]);

  return (
    <EvaReady>
      <div
        className='dome-xTree-actions dome-xSideBarSection-title'
        style={{ justifyContent: "flex-end" }}
      >
        <Buttons.IconButton
          size={16}
          icon={ "CHEVRON.CONTRACT" }
          title="Fold all"
          disabled={unfold === false}
          onClick={() => setUnfold(false)}
        />
        <Buttons.IconButton
          size={16}
          icon={ "CHEVRON.EXPAND" }
          title="Unfold all"
          disabled={unfold}
          onClick={() => setUnfold(true)}
        />
        {makeBadge(nodes.size)}
        <Dropdown control={ <Buttons.IconButton icon='FILTER' size={15}/> }>
          <Buttons.Multiselect>{itemsComp}</Buttons.Multiselect>
        </Dropdown>

        <Buttons.IconButton
          icon='TUNINGS'
          title='Configure selection'
          enabled={selection.length > 0}
          onClick={onResetMenu}
        />
      </div>

      <Tree.Tree
        unfoldAll={unfold}
        setUnfoldAll={setUnfold}
        selected={selectedFromValue.toString()}
        onClick={(id: string) => {
          const node = nodes.get(id);
          if(node) {
            if(node?.callstack.stack.length > 0) {
              const stmt = node.callstack.stack[0].stmt;
              const marker = States.getMarker(stmt).marker;
              States.setSelected(marker);
            }
            else States.setCurrentScope(node.decl);
          }
        }}
      >
        <Nodes tree={tree} visible={visibleKeys} onClick={flipSelected} />
      </Tree.Tree>

    </EvaReady>
  );

}

// ----------------------------------------------------------------------------
