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
import * as Ivette from 'ivette';

import GraphComponent from './graph';
import TreeComponent from './tree';

Ivette.registerGroup({
  id: 'fc.dive',
  label: 'Dive Plugin',
});

Ivette.registerComponent({
  id: 'fc.dive.graph',
  label: 'Dive Dataflow Graph',
  rank: 2,
  title: 'Data dependency graph according to an Eva analysis.',
  children: <GraphComponent />,
});

Ivette.registerComponent({
  id: 'fc.dive.tree',
  label: 'Dive Dataflow Tree',
  rank: 3,
  title: 'Data dependency tree according to an Eva analysis.',
  children: <TreeComponent />,
});

Ivette.registerView({
  id: 'fc.dive.dataflow',
  label: 'Dive Dataflow',
  rank: 5,
  layout: {
    'A': 'fc.kernel.astview',
    'B': 'fc.dive.graph',
    'C': 'fc.kernel.properties',
    'D': 'frama-c.kernel.locations',
  }
});
