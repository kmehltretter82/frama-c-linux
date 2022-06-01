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
import Draggable, {
  DraggableEvent,
  DraggableData,
  DraggableEventHandler
} from 'react-draggable';

export interface DragSourceProps {
  disabled?: boolean;
  handle?: string;
  children?: React.ReactNode;
}

/* eslint-disable no-console */
function trace(ctxt: string): DraggableEventHandler {
  return (e: DraggableEvent, d: DraggableData) => {
    console.log(ctxt, e, d);
  };
}
/* eslint-enable no-console */

export function DragSource(props: DragSourceProps): JSX.Element | null {
  const { disabled, handle, children } = props;
  return (
    <Draggable
      disabled={disabled}
      handle={handle}
      defaultClassName=''
      defaultClassNameDragged=''
      defaultClassNameDragging='dome-dragging'
      onStart={trace('onStart')}
      onDrag={trace('onDrag')}
      onStop={trace('onStop')}
    >
      {children}
    </Draggable>
  );
}
