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
import {
  DraggableCore,
  DraggableEventHandler
} from 'react-draggable';

export interface DragSourceProps {
  disabled?: boolean;
  handle?: string;
  children?: React.ReactNode;
  onStart?: () => void;
  onDrag?: (deltaX: number, deltaY: number) => void;
  onStop?: () => void;
}

interface Dragging {
  rootX: number,
  rootY: number,
  dragX: number,
  dragY: number,
}

export function DragSource(props: DragSourceProps): JSX.Element | null {
  const { disabled, handle, children } = props;
  const [dragging, setDragging] = React.useState<Dragging | undefined>();
  const onStart: DraggableEventHandler = (_, { x, y }) => {
    setDragging({
      rootX: x, rootY: y,
      dragX: x, dragY: y
    });
    if (props.onStart) props.onStart();
  };
  const onDrag: DraggableEventHandler = (_, { x, y }) => {
    if (dragging) {
      setDragging({ ...dragging, dragX: x, dragY: y });
      if (props.onDrag) {
        const deltaX = x - dragging.rootX;
        const deltaY = y - dragging.rootY;
        props.onDrag(deltaX, deltaY);
      }
    }
  };
  const onStop: DraggableEventHandler = () => {
    setDragging(undefined);
    if (props.onStop) props.onStop();
  };
  return (
    <DraggableCore
      disabled={disabled}
      handle={handle}
      onStart={onStart}
      onDrag={onDrag}
      onStop={onStop}
    >
      <div>{children}</div>
    </DraggableCore>
  );
}
