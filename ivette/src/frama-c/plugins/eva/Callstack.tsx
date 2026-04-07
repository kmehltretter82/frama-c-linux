/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

import * as Dome from 'dome';
import * as Tree from 'dome/frame/tree';
import { addPinnedMessage, Button, delPinnedMessage, PinnedMessage
} from 'dome/frame/toolbars';
import { IconButton } from 'dome/controls/buttons';
import { useGlobalState } from 'dome/data/states';
import { makeBadge } from 'dome/frame/sidebars';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as EvaAnalysis from 'frama-c/plugins/eva/api/analysis';
import * as Ast from 'frama-c/kernel/api/ast';
import { getDeclaration } from 'frama-c/states';

import * as EvaCS from './api/callstack';
import { EvaReady } from './components/AnalysisStatus';
import { CallstackState } from './valuetable';

// ----------------------------------------------------------------------------

const D = new Dome.Debug('eva.sidebar.callstack');
function error(k: string): void {
  D.error(`the node ${k} has not been create`);
}

interface CSNode {
  key: string;
  label: string;
  decl: Ast.decl;
  callstack: InfosCS;
  parentKey?: string;
  subTree: NodesMap;
}
type NodesMap = Map<string, CSNode>;

interface InfosCS extends EvaCS.callstackInfo { callstack: EvaCS.callstack}

// ----------------------------------------------------------------------------
// --- CallstackSelection message
// ----------------------------------------------------------------------------

const pinnedMessageId = 'EvaFilterCallstack';

function addMessage(count: number, remove: () => void): void {
  const pinnedMessageButton =
    <IconButton
      icon='TRASH'
      title='Remove callstack filter: show all callstacks'
      onClick={remove}
    />;
  const pinnedMessage: PinnedMessage = {
    id: pinnedMessageId,
    message:
      `${count} callstack${count === 1 ? ' is' : 's are'} currently shown`,
    actions: pinnedMessageButton
  };
  addPinnedMessage(pinnedMessage);
}

function delMessage(): void {
  delPinnedMessage(pinnedMessageId);
}

// ----------------------------------------------------------------------------
// --- Component Nodes
// ----------------------------------------------------------------------------

function getActions(
  id: EvaCS.callstack,
  onClick: (id: EvaCS.callstack) => void,
  currentCS?: EvaCS.callstack[]
): React.JSX.Element | null {
  const isSelected = currentCS?.includes(id);
  return (<>
    <IconButton
      icon='FILTER'
      title={isSelected ? 'Callstack is selected' : 'Filter the callstack'}
      kind={isSelected ? 'selected' : 'default'}
      style={isSelected ? {} : { fillOpacity: '0.2' } }
      onClick={() => onClick(id)}
    />
  </>
  );
}

interface CSNodesProps {
  tree: NodesMap,
  visible?: string[],
  onClick: (id: EvaCS.callstack) => void
}

function CSNodes({ tree, visible, onClick } : CSNodesProps): React.ReactNode {
  const [currentCS, ] = States.useSyncState(EvaCS.currentCallstacks);

  return [...tree].map(([, { key, label, callstack, subTree }]) => {
    const loc = States.getMarker(callstack.stack[0]?.stmt).sloc;
    const title = loc ? loc.base+': '+loc.line : '';
    return (
      <Tree.Node key={key} id={key} label={label} title={title}
        visible={visible?.includes(key) ?? true}
        actions={getActions(callstack.callstack, onClick, currentCS)}
      >
        { subTree && subTree.size > 0 ?
          <CSNodes tree={subTree} visible={visible} onClick={onClick} />
          : null
        }
      </Tree.Node>
    );
  });
}

// ----------------------------------------------------------------------------
// --- Infos Nodes
// ----------------------------------------------------------------------------

function getNode(key: string, cs: InfosCS): CSNode {
  const isEntryPoint = cs.stack.length === 0;
  const decl = isEntryPoint ? cs.entryPoint : cs.stack[0].callee;
  const parentkey = cs.stack[1]?.rank || cs.entryPoint || undefined;
  const label = getDeclaration(decl).name;
  return {
    key, label, decl,
    callstack: cs,
    parentKey: parentkey?.toString(),
    subTree: new Map()
  };
}

/** Return the Tree */
function getNodes(
  callstacks: InfosCS[],
): NodesMap {
  const nodes: NodesMap = new Map();

  callstacks.forEach(cs => {
    const key = cs.stack.length === 0
      ? cs.entryPoint
      : cs.stack[0].rank.toString();
    const newNode = getNode(key, cs);
    nodes.set(key, newNode);
  });

  return nodes;
}

/** Return the Tree */
function getTree(nodes: NodesMap): NodesMap {
  const tree: NodesMap = new Map();

  function addChildren(tree: NodesMap, cs: InfosCS, index: number): void {
    if(index < 0) return;
    const callsite = cs.stack[index];
    const key = callsite.rank.toString();

    if(!tree.has(key)) {
      const node = nodes.get(key);
      if(node) {
        tree.set(node.key, node);
        nodeInTree.push(node.key);
      }
    }
    const currNode = tree.get(key);
    if(currNode)
      addChildren(currNode.subTree, cs, index-1);
    else error(key);
  }
  const nodeInTree: string[] = [];

  nodes.forEach(node => {
    if(nodeInTree.includes(node.key)) return;
    const cs = node.callstack;
    const key = cs.entryPoint;

    if(!tree.has(key)) {
      tree.set(node.key, node);
      nodeInTree.push(node.key);
    }

    // treatment of children
    const currNode = tree.get(key);
    if(currNode)
      addChildren(currNode.subTree, cs, cs.stack.length-1);
    else error(key);
  });

  return tree;
}

/** Get details of callstacks */
async function getInfosCallstacks(
  callstacks: EvaCS.callstack[],
  callback: (a: InfosCS[]) => void
): Promise<void> {
  const infos = await Promise.all(callstacks.map(async (cs) => {
    const info = await Server.send(EvaCS.getCallstackInfo, cs);
    return { ...info, callstack: cs };
  }));
  callback(infos);
}

export function useCallstacks(): InfosCS[] {
  const status = Server.useStatus();
  const evaComputed = States.useSyncValue(EvaAnalysis.computationState);

  const [callstacks, setCallstacks] = React.useState<EvaCS.callstack[]>([]);
  const [CSInfos, setCallstacksInfos] = React.useState<InfosCS[]>([]);

  React.useEffect(() => {
    if(status === 'ON' && evaComputed === 'computed')
        Server.send(EvaCS.getAllCallstacks, []).then(a => setCallstacks(a));
    else setCallstacks([]);
  }, [evaComputed, status]);

  React.useEffect(() => {
    getInfosCallstacks(callstacks, setCallstacksInfos);
  }, [callstacks]);

  return CSInfos;
}

interface UseSelectedCS {
  selected: EvaCS.callstack[] | undefined,
  setSelected: (id: EvaCS.callstack) => void,
  reset: () => void
}

export function useSelectedCS(): UseSelectedCS {
  const [selected, _setSelected] = States.useSyncState(EvaCS.currentCallstacks);
  const reset = React.useCallback(() => { _setSelected([]); }, [_setSelected]);

  const setSelected  = React.useCallback((id: EvaCS.callstack): void => {
    if(!selected || selected.length === 0) _setSelected([id]);
    else if(selected.includes(id)) _setSelected(selected.filter(e => e !== id));
    else _setSelected([...selected, id]);
  }, [selected, _setSelected]);

  /** update warning when selected change */
  React.useEffect(() => {
    if (selected && selected.length > 0) addMessage(selected.length, reset);
    else delMessage();
  }, [selected, reset]);

  return { selected, setSelected, reset };
}

// ----------------------------------------------------------------------------
// --- Component CallstackSelection
// ----------------------------------------------------------------------------

export function CallstackSelection(): React.JSX.Element {
  const [ unfoldCS, setUnfoldCS ] = React.useState<boolean|undefined>(false);
  const [ selectedOnly, setSelectedOnly ] = React.useState(true);
  const { selected, setSelected, reset } = useSelectedCS();
  const CSInfos = useCallstacks();
  const [selectedFromValue, ] = useGlobalState(CallstackState);
  /** Nodes */
  const nodes = React.useMemo(() => getNodes(CSInfos), [CSInfos]);
  /** Tree */
  const tree = React.useMemo(() => getTree(nodes), [nodes]);

  /** Highlights the selected callstack from EvaValue  */
  const selectedId = React.useMemo(() => {
    return [...nodes.entries()]
      .find(([, v]) => v.callstack.callstack === selectedFromValue)
      ?.[1].key;
  }, [selectedFromValue, nodes]);

  /** List of keys for visible nodes */
  const visibleKeys = React.useMemo(() => {
    if(!selectedOnly || !selected || selected.length === 0)
      return undefined;
    const n = [...nodes.entries()];
    return selected ? selected.map(cs =>
      n.find(node => node[1].callstack.callstack === cs)?.[0] || ''
    ) : undefined;
  }, [selectedOnly, selected, nodes]);

  return (
    <EvaReady>
      <div
        className='dome-xTree-actions'
        style={{ justifyContent: "flex-end" }}
      >
        <IconButton
          size={16}
          icon={ "CHEVRON.CONTRACT" }
          title="Fold all"
          disabled={unfoldCS === false}
          onClick={() => setUnfoldCS(false)}
        />
        <IconButton
          size={16}
          icon={ "CHEVRON.EXPAND" }
          title="Unfold all"
          disabled={unfoldCS}
          onClick={() => setUnfoldCS(true)}
        />
        <Button
          label='Selet all'
          title='Select all callstacks'
          disabled={!selected || selected.length === 0}
          onClick={reset}
          />
        <IconButton
          icon='FILTER'
          title='Show selected callstack only'
          disabled={!selectedOnly && (!selected || selected.length === 0)}
          selected={selectedOnly}
          onClick={() => setSelectedOnly(e => !e)}
          />
        {makeBadge(nodes.size)}
      </div>

      <Tree.Tree
        unfoldAll={unfoldCS}
        setUnfoldAll={setUnfoldCS}
        selected={selectedId}
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
        <CSNodes tree={tree} visible={visibleKeys} onClick={setSelected} />
      </Tree.Tree>

    </EvaReady>
  );

}

// ----------------------------------------------------------------------------
