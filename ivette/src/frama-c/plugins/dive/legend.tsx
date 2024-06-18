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

import CytoscapeComponent from 'react-cytoscapejs';
import stylesheet from './style.json';

const elements = [
  {
    data: {
      id: "shape",
      label: "Node shape: memory"
    },
    classes: ["group"],
  },
  {
    data: {
      parent: "shape",
      label: "constant",
      nkind: 'const'
    },
    position: { x: 0, y: 0 }
  },
  {
    data: {
      parent: "shape",
      label: "scalar type"
    },
    position: { x: 0, y: 40 }
  },
  {
    data: {
      parent: "shape",
      label: "aggregate type",
      nkind: 'composite'
    },
    position: { x: 0, y: 80 }
  },
  {
    data: {
      parent: "shape",
      label: "set of addresses",
      nkind: 'scattered'
    },
    position: { x: 0, y: 120 }
  },
  {
    data: {
      parent: "shape",
      label: "analysis alarm",
      nkind: 'alarm'
    },
    position: { x: 0, y: 160 }
  },
  {
    data: {
      id: "color",
      label: "Node color: value cardinality"
    },
    classes: ["group"]
  },
  {
    data: {
      parent: "color",
      label: "unique value",
      range: 'singleton'
    },
    position: { x: 0, y: 230 }
  },
  {
    data: {
      parent: "color",
      label: "small range of values",
      stops: '0% 20% 20% 100%'
    },
    position: { x: 0, y: 270 }
  },
  {
    data: {
      parent: "color",
      label: "large range of values",
      stops: '0% 80% 80% 100%'
    },
    position: { x: 0, y: 310 }
  },
  {
    data: {
      parent: "color",
      label: "extreme range of values",
      range: 'wide'
    },
    position: { x: 0, y: 350 }
  },
  {
    data: {
      id: "outline",
      label: "Node outline color: taint analysis",
    },
    classes: ["group"]
  },
  {
    data: {
      parent: "outline",
      label: "directly tainted",
      taint: 'direct'
    },
    position: { x: 0, y: 420 }
  },
  {
    data: {
      parent: "outline",
      label: "indirectly tainted",
      taint: 'indirect'
    },
    position: { x: 0, y: 480 }
  },
];

const layout = {
  name: 'preset',
  fit: true,
  padding: 0,
};

const completeStylecheet = [
  ...stylesheet,
  {
    "selector": "node",
    "style": {
      "width": '140',
      "height": '20',
      "font-size": "14px",
    }
  },
  {
    "selector": ".group",
    "style": {
      "shape": "rectangle",
      "background-opacity": 0.0,
      "text-valign": "top",
      "text-halign": "center",
      "padding": "4px",
      "border-width": 0,
    }
  },
  {
    "selector": "#outline",
    "style": { "padding": "10px", }
  },
];

function Legend() : JSX.Element {
  return (
    <CytoscapeComponent
      elements={elements}
      layout={layout}
      className="legend"
      stylesheet={completeStylecheet}
      userPanningEnabled={false} /* No panning */
      userZoomingEnabled={false} /* No zoom */
      autounselectify={true} /* No node selection */
      autoungrabify={true} /* No node grab */
    />);
}

export default Legend;
