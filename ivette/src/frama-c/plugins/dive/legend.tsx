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

import React from 'react';
import _ from 'lodash';

import CytoscapeComponent from 'react-cytoscapejs';
import stylesheet from './style.json';

const elements = [
  { data: { label: "constant", nkind: 'const' } },
  { data: { label: "scalar memory" } },
  { data: { label: "structured memory", nkind: 'composite' } },
  { data: { label: "set of addresses", nkind: 'scattered' } },
  { data: { label: "analysis alarm", nkind: 'alarm' } },
  { data: { label: "unique value", range: 'singleton' } },
  { data: { label: "small range of values", stops: '0% 20% 20% 100%' } },
  { data: { label: "large range of values", stops: '0% 80% 80% 100%' } },
  { data: { label: "extreme range of values", range: 'wide' } },
  { data: { label: "directly tainted", taint: 'direct' } },
  { data: { label: "indirectly tainted", taint: 'indirect' } },
];

const layout = {
  name: 'grid',
  fit: true,
  padding: 5,
  avoidOverlapPadding: 15,
  cols: 1,
};

const completeStylecheet = [
  ...stylesheet,
  {
    "selector": "node",
    "style": { "width": 'label', }
  }
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
