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

// --------------------------------------------------------------------------
// --- Regions
// --------------------------------------------------------------------------

import React from 'react';
import * as Dot from 'dome/graph/diagram';
import * as States from 'frama-c/states';
import * as Region from './api';

function makeDiagram(_regions: Region.region[]) : Dot.DiagramProps {
  const nodes: Dot.Node[] = [];
  const edges: Dot.Edge[] = [];
  return { nodes, edges };
}

export function MemoryView(): JSX.Element {
  const scope = States.useCurrentScope();
  const regions = States.useRequest(Region.regions, scope) ?? [];
  const diagram = React.useMemo(() => makeDiagram(regions), [regions]);
  return <Dot.Diagram display={regions.length > 0} {...diagram} />;
}
