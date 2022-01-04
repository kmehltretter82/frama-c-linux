/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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
// --- Quarter-based Splitter
// --------------------------------------------------------------------------

/**
    @packageDocumentation
    @module dome/layout/qsplit
*/

import * as React from 'react';
import * as Utils from 'dome/misc/utils';
import { DraggableCore, DraggableEventHandler } from 'react-draggable';
import { AutoSizer, Size } from 'react-virtualized';

/* -------------------------------------------------------------------------- */
/* --- Q-Split Properties                                                 --- */
/* -------------------------------------------------------------------------- */

export interface QSplitProps {
  className?: string; /** Q-Split additional class. */
  style?: React.CSSProperties; /** Q-Split additional style. */
  A?: string; /** Q-Pane to layout in A-quarter. */
  B?: string; /** Q-Pane to layout in B-quarter. */
  C?: string; /** Q-Pane to layout in C-quarter. */
  D?: string; /** Q-Pane to layout in D-quarter. */
  H?: number; /** Horizontal panes ratio (range `0..1`, default `0.5`). */
  V?: number; /** Vertical panes ratio (range `0..1`, default `0.5`). */
  setPosition?: (H: number, V: number) => void; /** Dragging ratios callback. */
  children?: React.ReactNode;
  /** Q-Split contents. Shall be (possibly packed) Q-Panes.
      Other components would be layout as they are in the
     positionned `<div/>` of the Q-Split. */
}

/* -------------------------------------------------------------------------- */
/* --- Split Bars                                                         --- */
/* -------------------------------------------------------------------------- */

type Dragging = undefined | {
  position: number;
  anchor: number;
  offset: number;
};


interface QSplitterProps {
  hsplit: boolean;
  style: React.CSSProperties;
  dragging: Dragging;
  setDragging: (dragging: Dragging) => void;
  setPosition: (P: number) => void;
}

const HANDLE = '.dome-xSplitter-grab';
const HGRAB = 'dome-xSplitter-grab dome-xSplitter-hgrab';
const VGRAB = 'dome-xSplitter-grab dome-xSplitter-vgrab';
const HPOSR = 'dome-xSplitter-hline dome-xSplitter-hpos-R';
const VPOSR = 'dome-xSplitter-vline dome-xSplitter-vpos-R';
const DRAGGING = 'dome-color-dragging';
const DRAGZONE = 'dome-color-dragzone';

function QSplitter(props: QSplitterProps) {
  const { hsplit, style, dragging, setDragging, setPosition } = props;

  const onStart: DraggableEventHandler =
    (_evt, data) => {
      const startPos = hsplit ? data.node.offsetLeft : data.node.offsetTop;
      const anchor = hsplit ? data.x : data.y;
      setDragging({ position: startPos, offset: anchor, anchor });
    };

  const onDrag: DraggableEventHandler =
    (_evt, data) => {
      if (dragging) {
        const offset = hsplit ? data.x : data.y;
        setDragging({ ...dragging, offset });
      }
    };

  const onStop: DraggableEventHandler =
    (evt, _data) => {
      if (evt.metaKey || evt.altKey || evt.ctrlKey) {
        setPosition(0.5);
      } else if (dragging) {
        setPosition(dragging.position + dragging.offset - dragging.anchor);
      }
      setDragging(undefined);
    };

  const dragger = Utils.classes(
    hsplit ? HGRAB : VGRAB,
    dragging ? DRAGGING : DRAGZONE,
  );

  const css = hsplit ? HPOSR : VPOSR;

  return (
    <DraggableCore
      handle={HANDLE}
      onStart={onStart}
      onDrag={onDrag}
      onStop={onStop}
    >
      <div
        className={css}
        style={style}
      >
        <div className={dragger} />
      </div>
    </DraggableCore>
  );
}


/* -------------------------------------------------------------------------- */
/* --- Q-Split Engine                                                     --- */
/* -------------------------------------------------------------------------- */

type QSplitLayout = Map<string, React.CSSProperties>;
const QSplitContext = React.createContext<QSplitLayout>(new Map());
const NODISPLAY: React.CSSProperties = { display: 'none' };

const HSPLIT = (
  left: number,
  top: number,
  height: number,
) => ({ display: 'block', left, top, height });

const VSPLIT = (
  left: number,
  top: number,
  width: number,
) => ({ display: 'block', left, top, width });

const DISPLAY = (
  layout: QSplitLayout,
  id: string | undefined,
  left: number,
  width: number,
  top: number,
  height: number,
) => {
  if (id) layout.set(id, { display: 'block', left, width, top, height });
};

interface QSplitEngineProps extends QSplitProps { size: Size }

function QSplitEngine(props: QSplitEngineProps) {
  const [dragX, setDragX] = React.useState<Dragging>();
  const [dragY, setDragY] = React.useState<Dragging>();
  const layout: QSplitLayout = new Map();
  let hsplit: React.CSSProperties = NODISPLAY;
  let vsplit: React.CSSProperties = NODISPLAY;
  const { A, B, C, D, H = 0.5, V = 0.5, size, setPosition } = props;
  const { width, height } = size;
  const setX = React.useCallback((X: number) => {
    if (setPosition) setPosition(X / width, V);
  }, [setPosition, width, V]);
  const setY = React.useCallback((Y: number) => {
    if (setPosition) setPosition(H, Y / height);
  }, [setPosition, height, H]);
  const X = width * H;
  const Y = height * V;
  const RX = width - X - 1;
  const RY = height - Y - 1;
  const FULL = A !== undefined && A === D;
  const AB = A !== undefined && A === B;
  const AC = A !== undefined && A === C;
  const BD = B !== undefined && B === D;
  const CD = C !== undefined && C === D;
  //----------------------------------------
  // [ A ]
  //---------------------------------------
  if (FULL) {
    DISPLAY(layout, A, 0, width, 0, height);
  }
  //----------------------------------------
  // [ A - CD ]
  //---------------------------------------
  else if (AB && CD) {
    vsplit = VSPLIT(0, Y, width);
    DISPLAY(layout, A, 0, width, 0, Y);
    DISPLAY(layout, C, 0, width, Y + 1, RY);
  }
  //----------------------------------------
  // [ A | B ]
  //---------------------------------------
  else if (AC && BD) {
    hsplit = HSPLIT(X, 0, height);
    DISPLAY(layout, A, 0, X, 0, height);
    DISPLAY(layout, B, X + 1, RX, 0, height);
  }
  //----------------------------------------
  // [ A – C|D ]
  //----------------------------------------
  else if (AB) {
    hsplit = HSPLIT(X, 0, height);
    vsplit = VSPLIT(X, Y, RX);
    DISPLAY(layout, A, 0, width, 0, Y);
    DISPLAY(layout, C, 0, X, Y + 1, RY);
    DISPLAY(layout, D, X + 1, RX, Y + 1, RY);
  }
  //----------------------------------------
  // [ A | B-D ]
  //----------------------------------------
  else if (AC) {
    hsplit = HSPLIT(X, 0, height);
    vsplit = VSPLIT(X, Y, RY);
    DISPLAY(layout, A, 0, X, 0, height);
    DISPLAY(layout, B, X + 1, RX, 0, Y);
    DISPLAY(layout, D, X + 1, RX, Y + 1, RY);
  }
  //----------------------------------------
  // [ A-C | B ]
  //----------------------------------------
  else if (BD) {
    hsplit = HSPLIT(0, Y, RX);
    vsplit = VSPLIT(X, 0, width);
    DISPLAY(layout, A, 0, X, 0, Y);
    DISPLAY(layout, B, X + 1, RX, 0, height);
    DISPLAY(layout, C, 0, X, Y + 1, RY);
  }
  //----------------------------------------
  // [ A|B - C ]
  //----------------------------------------
  else if (CD) {
    hsplit = HSPLIT(X, 0, RX);
    vsplit = VSPLIT(0, Y, width);
    DISPLAY(layout, A, 0, X, 0, Y);
    DISPLAY(layout, B, X + 1, RX, 0, Y);
    DISPLAY(layout, C, 0, width, Y + 1, RY);
  }
  //----------------------------------------
  // [ A, B, C, D ]
  //----------------------------------------
  else {
    hsplit = HSPLIT(X, 0, height);
    vsplit = VSPLIT(0, Y, width);
    DISPLAY(layout, A, 0, X, 0, Y);
    DISPLAY(layout, B, X + 1, RX, 0, Y);
    DISPLAY(layout, C, 0, X, Y + 1, RY);
    DISPLAY(layout, D, X + 1, RX, Y + 1, RY);
  }
  //----------------------------------------
  // Rendering
  //----------------------------------------
  return (
    <QSplitContext.Provider value={layout}>
      <QSplitter
        key='SPLIT-H'
        hsplit={true}
        dragging={dragX}
        setDragging={setDragX}
        setPosition={setX}
        style={hsplit} />
      <QSplitter
        key='SPLIT-V'
        hsplit={false}
        dragging={dragY}
        setDragging={setDragY}
        setPosition={setY}
        style={vsplit} />
      {props.children}
    </QSplitContext.Provider>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Q-Split                                                            --- */
/* -------------------------------------------------------------------------- */

export function QSplit(props: QSplitProps) {
  const CONTAINER = Utils.classes('dome-xSplitter-container', props.className);
  return (
    <div className={CONTAINER} style={props.style}>
      <AutoSizer>
        {(size: Size) => (
          <QSplitEngine size={size} {...props} />
        )}
      </AutoSizer>
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Q-Pane                                                             --- */
/* -------------------------------------------------------------------------- */

export interface QPaneProps {
  id: string; /** Q-Pane Identifer. */
  className?: string; /** Additional class of the Q-Pane div. */
  style?: React.CSSProperties; /** Additional style of the Q-Pane div. */
  children?: React.ReactNode; /** Q-Pane contents. */
}

export function QPane(props: QPaneProps) {
  const layout = React.useContext(QSplitContext);
  const QPANE = Utils.classes('dome-xQPane', props.className);
  const QSTYLE = Utils.styles(props.style, layout?.get(props.id) ?? NODISPLAY);
  return <div className={QPANE} style={QSTYLE}>{props.children}</div>;
}

// --------------------------------------------------------------------------
