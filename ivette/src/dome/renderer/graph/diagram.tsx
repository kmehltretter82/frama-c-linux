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

import { Size } from 'react-virtualized';
import AutoSizer from 'react-virtualized-auto-sizer';

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export type Direction = 'LR' | 'TD';

export interface Node {
  /** Node identifier (unique). */
  id: string;
  /** Node label (optional). */
  label?: string;
}

export interface Edge {
  source: string /** Source node identifier */;
  target: string /** Target node identifier */;
}

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface DiagramProps {
  nodes: readonly Node[];
  edges: readonly Edge[];

  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: string;

  /** Top-Down (`'TD'`, default) or Left-Right (`'LR'`) direction. */
  direction?: Direction;

  /** Invoked when a node is selected. */
  onSelection?: (node: string, evt: MouseEvent) => void;

  /** Whether the Graph shall be displayed or not (defaults to true). */
  display?: boolean;

  /** Styling the Graph main div element. */
  className?: string;
}

/* -------------------------------------------------------------------------- */
/* --- d3-Graphviz Component                                              --- */
/* -------------------------------------------------------------------------- */

interface GraphvizProps extends DiagramProps { size: Size }

function Graphviz(_props: GraphvizProps): JSX.Element {
  return <></>;
}

/* -------------------------------------------------------------------------- */
/* --- Dome Diagram Component                                             --- */
/* -------------------------------------------------------------------------- */

export function Diagram(props: DiagramProps): JSX.Element {
  const { display = true } = props;

  return (
    <>
      {display && (
        <AutoSizer>
          {(size: Size) => (
            <div className={props.className}>
              <Graphviz size={size} {...props} />
            </div>
          )}
        </AutoSizer>
      )}
    </>
  );
}

/* -------------------------------------------------------------------------- */
