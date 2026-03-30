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

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as EvaAnalysis from 'frama-c/plugins/eva/api/analysis';
import * as Ast from 'frama-c/kernel/api/ast';
import { getDeclaration } from 'frama-c/states';

import * as EvaCS from './api/callstack';
import { EvaReady } from './components/AnalysisStatus';

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
}
type NodesMap = Map<string, CSNode>;

interface TreeCSNode extends CSNode {
  subTree: TreeMap;
}

type TreeMap = Map<string, TreeCSNode>;

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

interface CSTreeProps {
  tree: TreeMap,
  onClick: (id: string) => void
}

function CSTree({ tree, onClick } : CSTreeProps): React.ReactNode {
  const [currentCS, ] = States.useSyncState(EvaCS.currentCallstacks);

  function getActions(id: string)
  : React.JSX.Element | null {
    const isSelected = currentCS?.includes(parseInt(id, 10) as EvaCS.callstack);
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

  return [...tree].map(([, { key, label, callstack, subTree }]) => {
    const loc = States.getMarker(callstack.stack[0]?.stmt).sloc;
    const title = loc ? loc.base+': '+loc.line : '';
    return (
      <Tree.Node key={key} id={key} label={label}
        title={title}
        actions={getActions(callstack.callstack.toString())}
      >
        { subTree.size > 0 ?
          <CSTree tree={subTree} onClick={onClick} />
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
  return { key, label, decl, callstack: cs, parentKey: parentkey?.toString() };
}

/** Return the Tree */
function getNodes(callstacks: InfosCS[]): NodesMap {
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
function getTree(nodes: NodesMap): TreeMap {
  const tree: TreeMap = new Map();

  function addChildren(tree: TreeMap, cs: InfosCS, index: number): void {
    if(index < 0) return;
    const callsite = cs.stack[index];
    const key = callsite.rank.toString();

    if(!tree.has(key)) {
      const node = nodes.get(key);
      if(node) {
        const treeNode: TreeCSNode = Object.assign(node, {
          subTree: new Map()
        });
        tree.set(node.key, treeNode);
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
      const treeNode: TreeCSNode = Object.assign(node, {
        subTree: new Map()
      });
      tree.set(node.key, treeNode);
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

// ----------------------------------------------------------------------------
// --- Component CallstackSelection
// ----------------------------------------------------------------------------

export function CallstackSelection(): React.JSX.Element {
  const [ unfoldAll, setUnfoldAll ] = React.useState<boolean|undefined>(true);

  const status = Server.useStatus();
  const evaComputed = States.useSyncValue(EvaAnalysis.computationState);

  const [currCS, setCurrCS] = States.useSyncState(EvaCS.currentCallstacks);
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

  /** Nodes */
  const nodes = React.useMemo(() => getNodes(CSInfos), [CSInfos]);
  /** Tree */
  const tree = React.useMemo(() => getTree(nodes), [nodes]);

  /** Selected callstacks */
  const [selected, setSelected] = React.useState(new Set(currCS));
  const onClick = (id: string): void => {
    const intId = parseInt(id, 10) as EvaCS.callstack;
    selected.has(intId) ? selected.delete(intId): selected.add(intId);
    setSelected(new Set(selected));
  };

  /** Update callstacks selected */
  React.useEffect(() => { setCurrCS([...selected]); }, [selected, setCurrCS]);

  /** update warning when currentCS is not empty */
  React.useEffect(() => {
    if (currCS && currCS.length > 0)
      addMessage(currCS.length, () => {
        setCurrCS([]);
        setSelected(new Set([]));
      });
    else
      delMessage();
  }, [currCS, setCurrCS]);

  return (
    <EvaReady>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <div className='dome-xTree-actions'>
          <IconButton
            size={16}
            icon={ "CHEVRON.CONTRACT" }
            title="Fold all"
            disabled={unfoldAll === false}
            onClick={() => setUnfoldAll(false)}
          />
          <IconButton
            size={16}
            icon={ "CHEVRON.EXPAND" }
            title="Unfold all"
            disabled={unfoldAll}
            onClick={() => setUnfoldAll(true)}
          />
        </div>
        <Button
          label='Select All'
          disabled={selected.size === 0}
          onClick={() => setSelected(new Set())}
          />
      </div>
      <Tree.Tree
        unfoldAll={unfoldAll}
        setUnfoldAll={setUnfoldAll}
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
        <CSTree tree={tree} onClick={onClick}></CSTree>
      </Tree.Tree>
    </EvaReady>
  );

}

// ----------------------------------------------------------------------------
