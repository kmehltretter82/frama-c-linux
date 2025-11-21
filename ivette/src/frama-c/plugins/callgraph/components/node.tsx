/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import { NodeObject as NodeObject3D } from 'react-force-graph-3d';

import { classes } from 'dome/misc/utils';
import { LED } from 'dome/controls/displays';
import { Icon } from 'dome/controls/icons';
import { renderTaint } from 'frama-c/kernel/Properties';
import * as States from 'frama-c/states';

import { SelectedNodes, CGNode, SetSelectedNodes } from "../definitions";

const getRenderTaint = (node: NodeObject3D<CGNode>): JSX.Element | null => {
  if(!node.taintStatus || node.taintStatus.length < 1) return null;

  const taintTag: States.Tag = { name: '' };
  if(node.taintStatus.find((elt) => elt.name === "direct_taint")) {
    taintTag.name = "direct_taint";
    taintTag.descr = 'Direct taint';
  }
  else if(node.taintStatus.find((elt) => elt.name === "indirect_taint")) {
    taintTag.name = "indirect_taint";
    taintTag.descr = 'Indirect taint';
  }
  else if(node.taintStatus.find((elt) => elt.name === "error")) {
    taintTag.name = "error";
    taintTag.descr = 'Error';
  }

  return taintTag.name !== '' ? renderTaint(taintTag) : null;
};

const getNodeAlarms = (node: CGNode): JSX.Element => {
  return <>
    {node.alarmStatuses && node.alarmStatuses.invalid > 0 && LED({
      status: "negative",
      title: node.alarmStatuses.invalid+" invalid",
      })}
    {node.alarmStatuses && node.alarmStatuses.unknown > 0 && LED({
      status: "warning",
      title: node.alarmStatuses.unknown+" unknown",
      })}
  </>;
};

const getNodeText = (node: CGNode): string => {
  return node.label || "";
};

export const getNode = (
  node: NodeObject3D<CGNode>,
  selectedNodesState: [SelectedNodes, SetSelectedNodes],
  multiSelectFunction:
    (selectedNodesState: [SelectedNodes, SetSelectedNodes],
    id: string, event: MouseEvent | React.MouseEvent) => void
): JSX.Element => {
  const [selectedNodes, ] = selectedNodesState;
  const className = classes(
    'node-graph',
    selectedNodes.has(node.id) && "node-selected"
  );

  const select = (event: React.MouseEvent): void => {
    multiSelectFunction(selectedNodesState, node.id, event);
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
      { getRenderTaint(node) }
    </div>
  );
};
