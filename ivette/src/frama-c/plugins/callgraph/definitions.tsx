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
import { Edge, Node } from 'dome/graph/graph';
import * as Eva from 'frama-c/plugins/eva/api/general';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import {
  NodeObject as NodeObject3D,
  LinkObject as LinkObject3D,
} from 'react-force-graph-3d';

import { IThreeStateButton } from "./components/threeStateButton";

export type ModeDisplay = "all" | "linked" | "selected"

export type SelectedNodesData = Set<string>
export interface SelectedNodes {
  tic: boolean;
  set: SelectedNodesData;
}
export interface SetSelectedNodes
  extends React.Dispatch<React.SetStateAction<SelectedNodes>>{}

export interface CallGraphFunc {
  /** Update the selected nodes state */
  updateSelectedNodes: (newSet: SelectedNodesData) => void;
  /** Check if a node is selected */
  isSelectedNode: (id: string) => boolean;
  /** MultiSelect on node click */
  onNodeClickMultiSelect:
    (id: string, event: MouseEvent | React.MouseEvent) => void;
  /** Get link color */
  getLinkColor: (node: LinkObject3D<CGNode, CGLink>) => string;
  /** Get link visibility */
  getLinkVisibility: (node: LinkObject3D<CGNode, CGLink>) => boolean;
  /** Get link width */
  getLinkWidth: (node: LinkObject3D<CGNode, CGLink>) => number;
  /** Get node visibility */
  getNodeVisibility: (id: string) => boolean;
}

export interface CGNode extends Node {
  /** Coverage of the Eva analysis */
  coverage?: { reachable: number, dead: number };
  /** Alarms raised by the Eva analysis by category */
  alarmCount?: Eva.alarmEntry[];
  /** Alarms statuses emitted by the Eva analysis */
  alarmStatuses?: Eva.statusesEntry;
  /** Taint status */
  taintStatus?: States.Tag[];
  /** is Recursive function */
  isRecursive?: boolean;
}

export interface CGLink extends Edge {}

export interface CGData {
  nodes: CGNode[];
  links: CGLink[];
}

type nodeType = "parents" | "children";

function getIDFromLink(link: LinkObject3D<CGNode, CGLink>)
: {sourceId:string, targetId: string} {
  const sourceId = typeof link.source === 'string' ?
    link.source : (link.source as NodeObject3D<CGNode>).id;
  const targetId = typeof link.target === 'string' ?
    link.target : (link.target as NodeObject3D<CGNode>).id;
  return { sourceId, targetId };
}

export const callGraphFunction = (
  selectNodes: [SelectedNodes, SetSelectedNodes],
  graphData: CGData,
  displayMode: ModeDisplay,
  style: CSSStyleDeclaration,
  selectedParents: IThreeStateButton,
  selectedChildren: IThreeStateButton,
): CallGraphFunc => {
  const [selectedNodes, setSelectedNodes] = selectNodes;
  const { links } = graphData;

  function removeCycle(toTraited: string[], ids: string[]): string[] {
    const ret: string[] = [];
    for (const elt of toTraited) {
      if(!ids.includes(elt)) ret.push(elt);
    }
    return ret;
  }

  function getNextNodes(type: nodeType, ids: string[]): string[] {
    const ret: string[] = [];
    for (const elt of links) {
      const { sourceId, targetId } = getIDFromLink(elt);

      if(type === "children" && ids.includes(sourceId))
          ret.push(targetId);
      else if (type === "parents" && ids.includes(targetId))
          ret.push(sourceId);
    }
    return ret;
  }

  function getNodes(type: nodeType, depth?: number): string[] {
    let ids: string[] = Array.from(selectedNodes.set);
    if (depth === 0) return ids;
    let nodes = ids;
    let i = 0;
    do {
      const news =
        getNextNodes(type, nodes).map((elt) => nodes.includes(elt) ? "" : elt);
      nodes = removeCycle(news, ids);
      ids = ids.concat(news);
      i++;
    } while(nodes.length > 0 && (depth === undefined || i < depth));

    return ids;
  }

  function getDepth(v: IThreeStateButton): number | undefined {
    return v.active ? (v.max ? undefined : (v.value ? v.value : 0)) : 0;
  }

  const successor = getNodes("children", getDepth(selectedChildren));
  const predecessors = getNodes("parents", getDepth(selectedParents));

  const updateSelectedNodes = (newSet: SelectedNodesData): void => {
    setSelectedNodes((elt) => {
      return { tic: !elt.tic, set: new Set(newSet) };
    });
  };

  const isSelectedNode = (id: string): boolean => selectedNodes.set.has(id);

  const onNodeClickMultiSelect = (
    id: string, event: MouseEvent | React.MouseEvent
  ): void => {
    const s = selectedNodes.set;
    if (event.ctrlKey) { // multi-selection
      s.has(id) ? s.delete(id) : s.add(id);
    } else if (event.altKey) {
      States.setCurrentScope(id as Ast.decl);
      return;
    } else { // single-selection
      s.clear();
      s.add(id);
    }
    updateSelectedNodes(s);
  };

  const getLinkColor = (node: LinkObject3D<CGNode, CGLink>): string => {
    const { sourceId, targetId } = getIDFromLink(node);
    let color = "grey";
    const isDst = isSelectedNode(targetId);
    const isSrc = isSelectedNode(sourceId);

    if(isDst && isSrc)
      color = style.getPropertyValue('--graph-ed-color-green');
    else if(isDst)
      color = style.getPropertyValue('--graph-ed-color-red');
    else if(isSrc)
      color = style.getPropertyValue('--graph-ed-color-blue');
    return color;
  };

  const getLinkVisibility = (node: LinkObject3D<CGNode, CGLink>): boolean => {
    const { sourceId, targetId } = getIDFromLink(node);
    switch(displayMode) {
      case "selected":
        return Boolean(
          (successor.includes(sourceId) || predecessors.includes(sourceId)) &&
          (successor.includes(targetId) || predecessors.includes(targetId))
        );
      case "linked":
      case "all":
      default: return true;
    }
  };

  const getLinkWidth = (node: LinkObject3D<CGNode, CGLink>): number => {
    const { sourceId, targetId } = getIDFromLink(node);
    return (isSelectedNode(sourceId) || isSelectedNode(targetId)) ? 2 : 1;
  };

  const getNodeVisibility = (id: string): boolean => {
    switch(displayMode) {
      case "linked":
        if(!links.find((elt:LinkObject3D<CGNode, CGLink>) => {
          const { sourceId, targetId } = getIDFromLink(elt);
            return Boolean(sourceId === id || targetId === id);
          }
        )) return false;
        return true;
      case "selected":
        return successor.includes(id) || predecessors.includes(id);
      default: return true;
    }
  };

  return {
    updateSelectedNodes: updateSelectedNodes,
    isSelectedNode: isSelectedNode,
    onNodeClickMultiSelect: onNodeClickMultiSelect,
    getLinkColor: getLinkColor,
    getLinkWidth: getLinkWidth,
    getLinkVisibility: getLinkVisibility,
    getNodeVisibility: getNodeVisibility,
  };
};
