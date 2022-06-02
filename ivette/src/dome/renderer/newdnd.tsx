/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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

/**
   @packageDocumentation
   @module dome/newdnd
   @description

   D&D Facilities
 */

import React from 'react';
import { classes, styles } from 'dome/misc/utils';
import {
  DraggableCore,
  DraggableEventHandler
} from 'react-draggable';

/**
   Current dragging informations:
   - `rootX,rootY` is the position where dragging started;
   - `dragX,dragY` is the current dragging position;
   - `rect` is the original DOM Rectangle of the dragged HTML node.

   Hence, the relative move during dragging is simply `(dragX-rootX,dragY-rootY)`.
 */
export interface Dragging {
  rootX: number;
  rootY: number;
  dragX: number;
  dragY: number;
  rect: DOMRect;
}

/**
   Can be used to conditionally render an element wrt to dragging informations.
 */
export type DraggingRenderer = (d: Dragging | undefined) => JSX.Element;

interface OverlayRendering {
  outerClass?: string;
  innerClass?: string;
  outerStyle?: React.CSSProperties;
  innerStyle?: React.CSSProperties;
}

function RenderOverlay(
  props: DragSourceProps,
  dragging: Dragging | undefined,
): OverlayRendering {
  const { className, style } = props;
  if (dragging) {
    const { dragX, dragY, rootX, rootY, rect } = dragging;
    const { left, top, width, height } = rect;
    const {
      zIndex = 1,
      offsetX = 0,
      offsetY = 0,
      classDragged = 'dome-dragged',
      classDragging = 'dome-dragging',
    } = props;
    const position: React.CSSProperties = {
      position: 'fixed',
      left: left + offsetX + dragX - rootX,
      top: top + offsetY + dragY - rootY,
      width, height, zIndex, margin: 0
    };
    const holder = { width, height };
    return {
      outerClass: classes(className, classDragged),
      innerClass: classes(className, classDragging),
      outerStyle: styles(style, props.styleDragged, holder),
      innerStyle: styles(style, props.styleDragging, position),
    };
  }
  return { outerClass: className, outerStyle: style }
}

export interface DragSourceProps {
  /** Disabled dragging. */
  disabled?: boolean;
  /** Class of the element from where a drag can be initiated. */
  handle?: string;
  /** Class of the DragSource elements. */
  className?: string;
  /** Style of the DragSource elements. */
  style?: React.CSSProperties;
  /** Additional class for the dragged (initial) element (default is `'dome-dragged'`). */
  classDragged?: string;
  /** Additional class for the dragging (moved) element (default is `'dome-dragging'`) */
  classDragging?: string;
  /** Additional style for the dragged (initial) element. */
  styleDragged?: React.CSSProperties;
  /** Additional style for the dragging (moved) element. */
  styleDragging?: React.CSSProperties;
  /** X-offset when dragging (defaults to 0). */
  offsetX?: number;
  /** Y-offset when dragging (defaults to 0). */
  offsetY?: number;
  /** Z-index when dragging (defaults to 1). */
  zIndex?: number;
  /** Callback when drag is initiated. */
  onStart?: () => void;
  /** Callback current dragging. */
  onDrag?: (dragging: Dragging) => void;
  /** Callback when drag is interrupted. */
  onStop?: () => void;
  /** Inner contents of the DragSource element. */
  children?: React.ReactNode | DraggingRenderer;
}

/**
   This container can be dragged around all over the application window. Its
   content is rendered inside a double `<div/>`, the outer one being fixed when
   dragged, and the inner one being moved around when dragging.

   The content can be rendered conditionnaly by using a function.
 */
export function DragSource(props: DragSourceProps): JSX.Element | null {
  //--- Props
  const { disabled, handle, children } = props;
  const { onStart, onDrag, onStop } = props;
  //--- Dragging State
  const [dragging, setDragging] = React.useState<Dragging | undefined>();
  //--- onStart
  const handleStart: DraggableEventHandler = React.useCallback(
    (_, { x, y, node }) => {
      setDragging({
        rootX: x, rootY: y,
        dragX: x, dragY: y,
        rect: node.getBoundingClientRect(),
      });
      if (onStart) onStart();
    }, [onStart]);
  //--- onDrag
  const handleDrag: DraggableEventHandler = React.useCallback(
    (_, { x, y }) => {
      if (dragging) {
        setDragging({ ...dragging, dragX: x, dragY: y });
        if (onDrag) onDrag(dragging);
      }
    }, [dragging, onDrag]);
  //--- onStop
  const handleStop: DraggableEventHandler = React.useCallback(
    () => {
      setDragging(undefined);
      if (onStop) onStop();
    }, [onStop]);
  //--- Renderer
  const render = RenderOverlay(props, dragging);
  return (
    <DraggableCore
      disabled={disabled}
      handle={handle}
      onStart={handleStart}
      onDrag={handleDrag}
      onStop={handleStop}
    >
      <div className={render.outerClass} style={render.outerStyle}>
        <div className={render.innerClass} style={render.innerStyle}>
          {typeof (children) === 'function' ? children(dragging) : children}
        </div>
      </div>
    </DraggableCore>
  );
}
