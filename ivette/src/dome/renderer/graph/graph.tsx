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
// import other libs
import './style.css';

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export interface Attributes {
  label?: string;
  title?: string;
  className?: string;
}

export type Shape = "dot" | "box" | "circle";
export type ArrowType = "--" | "->" | "<-" | "<->";
export type Layout = "2D" | "3D";

export interface Node extends Attributes {

  /** Node identifier (unique). */
  id: string;

  /** defaults to `"dot"` */
  shape?: Shape;

}

export interface Edge extends Attributes {

  fromNode: string;
  toNode: string;

  /** defaults to `"->"` */
  arrowType?: ArrowType;

}

export type Callback = () => void;
export type SelectionCallback = (node: string, evt: React.MouseEvent) => void;

/* -------------------------------------------------------------------------- */
/* --- Graph Implementation                                               --- */
/* -------------------------------------------------------------------------- */

// TO BE COMPLETE

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface GraphProps {
  nodes: readonly Node[];
  edges: readonly Edge[];

  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: string;

  /** Force recomputing layout. */
  reset?: boolean;

  /**
     Zoom factor.
     Affects the viewport and the dimension of the nodes.
     When the zoom factor becomes to small, labels might be discarded.
   */
  zoom?: number;

  /** Kayout engine. */
  layout?: Layout;

  /** Invoked when a node is selected. */
  onSelection?: Callback;

  /** Invoked after layout is computed (typically used after a reset). */
  onReady?: Callback;

  /** Whether the Graph shall be displayed or not (defaults to true). */
  display?: boolean;

  /** Styling the Graph main div element. */
  className?: string;

  /** Elements to be inserted right inside the Graph main div element. */
  children?: React.ReactNode;
}

/* -------------------------------------------------------------------------- */
/* --- Graph Component                                                    --- */
/* -------------------------------------------------------------------------- */

export function Graph(_props: GraphProps): JSX.Element {
  return <></>;
}

/* -------------------------------------------------------------------------- */
