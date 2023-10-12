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
import { GraphComponent } from './graph';

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

Ivette.registerComponent({
  id: 'frama-c.plugins.dive',
  label: 'Dive Dataflow',
  group: 'frama-c.plugins',
  rank: 2,
  title:
    'Data dependency graph according to an Eva analysis.\nNodes color ' +
    'represents the precision of the values inferred by Eva.',
  children: <GraphComponent />,
});

Ivette.registerView({
  id: 'dive',
  label: 'Dive Dataflow',
  rank: 5,
  layout: [
    ['frama-c.astview', 'frama-c.plugins.dive'],
    ['frama-c.properties', 'frama-c.locations'],
  ],
});

// --------------------------------------------------------------------------
