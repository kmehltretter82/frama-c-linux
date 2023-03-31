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

import React, { useState } from 'react';
import _ from 'lodash';
import * as Ivette from 'ivette';
import * as Server from 'frama-c/server';

import * as API from './api';

import Cytoscape from 'cytoscape';
import CytoscapeComponent from 'react-cytoscapejs';
import 'frama-c/plugins/dive/cytoscape_libs';
import 'cytoscape-panzoom/cytoscape.js-panzoom.css';

import style from './graph-style.json';
import { useSyncValue } from 'frama-c/states';

import gearsIcon from 'frama-c/plugins/eva/images/gears.svg';
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

(style as unknown[]).push({
    selector: 'node',
    style: {width: getWidth}
  });


// --------------------------------------------------------------------------
// --- Graph
// --------------------------------------------------------------------------

function convertGraph(graph: API.graph): object[] {
  const elements = [];
  for (const v of graph.vertices) {
    elements.push({data: {...v, id:v.kf}});
  }
  for (const e of graph.edges) {
    elements.push({data: {source: e.src, target: e.dst}});
  }
  console.log(elements);
  return elements;
}


function Callgraph() : JSX.Element { 
  const isComputed = useSyncValue(API.isComputed);
  const graph = useSyncValue(API.callgraph);
  const [cy, setCy] = useState<Cytoscape.Core>();
  const layout = {name: 'cola', nodeSpacing: 32};

  if (isComputed === false) {
    Server.send(API.compute, null);
    return (<img src={gearsIcon} className="callgraph-computing" />);
  }
  else if (graph !== undefined) {
    return (
      <CytoscapeComponent
        elements={convertGraph(graph)}
        stylesheet={style}
        cy={setCy}
        layout={layout}
        style={{width: '100%', height: '100%'}}
      />);  
  }
  else {
    return (<></>);
  }
}


// --------------------------------------------------------------------------
// --- Ivette Component
// --------------------------------------------------------------------------

function CallgraphComponent(): JSX.Element {
  // Component
  return (
    <>
      <Ivette.TitleBar />
      <Callgraph />
    </>
  );
}


Ivette.registerComponent({
  id: 'frama-c.plugins.callgraph',
  label: 'Call Graph',
  group: 'frama-c.plugins',
  rank: 3,
  title:
    'Display a graph showing calls between functions.',
  children: <CallgraphComponent />,
});
