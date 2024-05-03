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
import _ from 'lodash';
import * as Ivette from 'ivette';
import * as Server from 'frama-c/server';

import * as AstAPI from 'frama-c/kernel/api/ast';
import * as CgAPI from './api';
import * as ValuesAPI from 'frama-c/plugins/eva/api/values';

import Cy from 'cytoscape';
import CytoscapeComponent from 'react-cytoscapejs';
import 'frama-c/plugins/dive/cytoscape_libs';
import 'cytoscape-panzoom/cytoscape.js-panzoom.css';
import style from './graph-style.json';

import { useGlobalState } from 'dome/data/states';
import * as States from 'frama-c/states';

import gearsIcon from 'frama-c/plugins/eva/images/gears.svg';
import { CallstackState } from 'frama-c/plugins/eva/valuetable';

import './callgraph.css';


// --------------------------------------------------------------------------
// --- Nodes label measurement
// --------------------------------------------------------------------------

/* eslint-disable @typescript-eslint/no-explicit-any */
function getWidth(node: any): string {
  const padding = 10;
  const min = 50;
  const canvas = document.querySelector('canvas[data-id="layer2-node"]');
  if (canvas instanceof HTMLCanvasElement) {
    const context = canvas.getContext('2d');
    if (context) {
      const fStyle = node.pstyle('font-style').strValue;
      const weight = node.pstyle('font-weight').strValue;
      const size = node.pstyle('font-size').pfValue;
      const family = node.pstyle('font-family').strValue;
      context.font = `${fStyle} ${weight} ${size}px ${family}`;
      const width = context.measureText(node.data('id')).width;
      return `${Math.max(min, width + padding)}px`;
    }
  }
  return `${min}px`;
}
/* eslint-enable @typescript-eslint/no-explicit-any */

(style as unknown[]).push({
    selector: 'node',
    style: { width: getWidth }
  });


// --------------------------------------------------------------------------
// --- Graph
// --------------------------------------------------------------------------

function edgeId(source: AstAPI.decl, target: AstAPI.decl): string {
  return `${source}-${target}`;
}

function convertGraph(graph: CgAPI.graph): object[] {
  const elements = [];
  for (const v of graph.vertices) {
    elements.push({ data: { ...v, id: v.decl } });
  }
  for (const e of graph.edges) {
    const id = edgeId(e.src, e.dst);
    elements.push({ data: { ...e, id, source: e.src, target: e.dst } });
  }
  return elements;
}

function selectNode(cy: Cy.Core, nodeId: States.Scope): void {
  const className = 'marker-selected';
  cy.$(`.${className}`).removeClass(className);
  if (nodeId) {
    cy.$(`node[id='${nodeId}']`).addClass(className);
  }
}

function selectCallstack(cy: Cy.Core, callstack: ValuesAPI.callsite[]): void {
  const className = 'callstack-selected';
  cy.$(`.${className}`).removeClass(className);
  callstack.forEach((call) => {
    cy.$(`node[id='${call.callee}']`).addClass(className);
    if (call.caller) {
      const id = edgeId(call.caller, call.callee);
      cy.$(`edge[id='${id}']`).addClass(className);
    }
  });
}

function Callgraph() : JSX.Element {
  const isComputed = States.useSyncValue(CgAPI.isComputed);
  const graph = States.useSyncValue(CgAPI.callgraph);
  const [cy, setCy] = React.useState<Cy.Core>();
  const [cs] = useGlobalState(CallstackState);
  const callstack = States.useRequest(
    ValuesAPI.getCallstackInfo, cs, { onError: [] }
  );
  const scope = States.useCurrentScope();
  const layout = { name: 'cola', nodeSpacing: 32 };
  const computedStyle = getComputedStyle(document.documentElement);
  const styleVariables =
    { ['code-select']: computedStyle.getPropertyValue("--code-select") };

  const completeStyle = [
    ...style,
    {
      "selector": ".marker-selected",
      "style": { "background-color": styleVariables['code-select'] }
    }
  ];

  // Marker selection
  React.useEffect(() => { cy && selectNode(cy, scope); }, [cy, scope]);

  // Callstack selection
  React.useEffect(() => {
    cy && selectCallstack(cy, callstack ?? []);
  }, [cy, callstack]);

  // Click on graph
  React.useEffect(() => {
    if (cy) {
      cy.off('click');
      cy.on('click', 'node', (event) => {
        const { id } = event.target.data();
        States.setCurrentScope(id);
      });
    }
  }, [cy]);

  if (isComputed === false) {
    Server.send(CgAPI.compute, null);
    return (<img src={gearsIcon} className="callgraph-computing" />);
  }
  else if (graph !== undefined) {
    return (
      <CytoscapeComponent
        elements={convertGraph(graph)}
        stylesheet={completeStyle}
        cy={setCy}
        layout={layout}
        style={{ width: '100%', height: '100%' }}
      />);
  }
  else {
    return (<></>);
  }
}


// --------------------------------------------------------------------------
// --- Ivette Component
// --------------------------------------------------------------------------

Ivette.registerComponent({
  id: 'fc.callgraph',
  label: 'Call Graph',
  title:
    'Display a graph showing calls between functions.',
  children: <Callgraph />,
});
