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
import { NodeObject as NodeObject3D } from 'react-force-graph-3d';

import { classes } from 'dome/misc/utils';
import { LED } from 'dome/controls/displays';
import { Icon } from 'dome/controls/icons';
import { renderTaint } from 'frama-c/kernel/Properties';

import { SelectedNodes, CGNode } from "../definitions";

const isTaintedScope = (node: NodeObject3D<CGNode>): boolean => {
  return Boolean(
    node.taintStatus && node.taintStatus.length > 0 &&
    (
      node.taintStatus.find((elt) => elt.name === "direct_taint") ||
      node.taintStatus.find((elt) => elt.name === "indirect_taint")
    )
  );
};

const getNodeAlarms = (node: CGNode): JSX.Element => {
  return <>
    <div>
      {node.alarmStatuses && node.alarmStatuses.invalid > 0 && LED({
        status: "negative",
        title: node.alarmStatuses.invalid+" invalid",
        })}
      {node.alarmStatuses && node.alarmStatuses.unknown > 0 && LED({
        status: "warning",
        title: node.alarmStatuses.unknown+" unknown",
        })}
    </div>
  </>;
};

const getNodeText = (node: CGNode): string => {
  return node.label || "";
};

export const getNode = (
  node: NodeObject3D<CGNode>,
  selectedNodes: SelectedNodes,
  multiSelectFunction:
    (id: string, event: MouseEvent | React.MouseEvent) => void
): JSX.Element => {
  const className = classes(
    'node-graph',
    selectedNodes.set.has(node.id) && "node-selected"
  );

  const select = (event: React.MouseEvent): void => {
    multiSelectFunction(node.id, event);
  };

  return (
    <div className={className} onClick={select}>
      <div>
        { getNodeText(node) }
      </div>
      { node.isRecursive &&
        <Icon
          id={"REDO"} size={11}
          fill={"orange"} title={"Recursive function"}
        />
      }
      { getNodeAlarms(node) }
      { isTaintedScope(node) && renderTaint({ name: "direct_taint" }) }
    </div>
  );
};
