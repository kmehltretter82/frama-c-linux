/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

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

function isEntryPoint(cs: InfosCS): boolean { return cs.stack.length === 0; }

function compareStack(a: EvaCS.callsite[], b: EvaCS.callsite[]): boolean {
  if(a.length !== b.length) return false;
  return a.every((e, i) => (
    e.callee === b[i].callee
    && e.caller === b[i].caller
    && e.stmt === b[i].stmt
  ));
}

function getParentKey(cs: InfosCS, callstacks: InfosCS[]): string | undefined {
  if(isEntryPoint(cs)) return undefined;
  return callstacks.find(e => (
    e.entryPoint === cs.entryPoint
    && compareStack(e.stack, cs.stack.slice(1))
  ))?.callstack.toString();
}

function getNode(key: string, cs: InfosCS, callstacks: InfosCS[]): CSNode {
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
function getTree( callstacks: InfosCS[]): {nodes: NodesMap, tree: NodesMap} {
  const nodes: NodesMap = new Map();
  const tree: NodesMap = new Map();

  // Create nodes and tree
  callstacks.forEach(cs => {
    const key = cs.callstack.toString();
    const newNode = getNode(key, cs, callstacks);
    nodes.set(key, newNode);
    // The tree contains only entry point
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
  const [ showSelectedOnly, setShowSelectedOnly ] = React.useState(false);
  const { selected, setSelected, reset } = useSelectedCS();
  const CSInfos = useCallstacks();
  const [selectedFromValue, ] = useGlobalState(CallstackState);

  /** Tree */
  const { nodes, tree } = React.useMemo(() => getTree(CSInfos), [CSInfos]);

  /** List of keys for visible nodes */
  const visibleKeys = React.useMemo(() => {
    return !showSelectedOnly || !selected || selected.length === 0
      ? undefined
      : selected.map(s => s.toString());
  }, [showSelectedOnly, selected]);

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
          label='Selected only'
          title='Show selected callstacks only'
          disabled={!showSelectedOnly && (!selected || selected.length === 0)}
          selected={showSelectedOnly}
          onClick={() => setShowSelectedOnly(e => !e)}
          />
        {makeBadge(nodes.size)}
        <IconButton
          icon='FILTER'
          title='Select all callstacks'
          disabled={!selected || selected.length === 0}
          onClick={reset}
          />
      </div>

      <Tree.Tree
        unfoldAll={unfoldCS}
        setUnfoldAll={setUnfoldCS}
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
        <CSNodes tree={tree} visible={visibleKeys} onClick={setSelected} />
      </Tree.Tree>

    </EvaReady>
  );

}

// ----------------------------------------------------------------------------
