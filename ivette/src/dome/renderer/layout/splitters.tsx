/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Splitters
// --------------------------------------------------------------------------

/**
    @packageDocumentation
    @module dome/layout/splitters
*/

import * as React from 'react';
import * as Dome from 'dome';
import * as Utils from 'dome/misc/utils';
import { DraggableCore, DraggableEventHandler } from 'react-draggable';
import AutoSizer, { Size } from 'react-virtualized-auto-sizer';

// --------------------------------------------------------------------------
// --- Splitter
// --------------------------------------------------------------------------

export interface SplitterBaseProps {
  /** Window settings to store the splitter position. */
  settings?: string;
  /** Ratio or size depending of the splitter:
     - for 'horizontal' or 'vertical' split, ratio between the two panels;
     - for other splits, size of the foldable component. */
  defaultPosition?: number;
  /** Minimal margin from container edges (minimum `32`). */
  margin?: number;
  /** Splitter children components. */
  children: [JSX.Element, JSX.Element];
}

export interface SplitterFoldProps extends SplitterBaseProps {
  /**
     Visibility of the foldable component.
     Only applies to left, right, top and bottom layout.
   */
  unfold?: boolean;
  /**
     Allow the foldable component to be resized down to `0`
     while keeping the splitter handle visible.
     Only applies to left, right, top and bottom splitters.
   */
  allowResizeToZero?: boolean;
  /**
     Controlled splitter position. When omitted, the splitter stores
     its position in `settings`.
     For foldable splitters with `allowResizeToZero`, `0` collapses the
     foldable pane without hiding the splitter handle.
   */
  position?: number;
  /**
     Callback used together with `position` for controlled splitters.
     Called with the effective pane size or ratio after dragging.
   */
  onPosition?: (position: number) => void;
}

export enum Direction {
  /** Horizontal split. */
  HORIZONTAL,
  /** Vertical split. */
  VERTICAL,
  /** Stacked, foldable left component. */
  LEFT,
  /** Stacked, foldable right component. */
  RIGHT,
  /** Stacked, foldable top component. */
  TOP,
  /** Stacked, foldable bottom component. */
  BOTTOM,
}

export interface SplitterDirProps extends SplitterFoldProps {
  /** Direction of the splitter. */
  direction: Direction;
}

/* --------------------------------------------------------------------------*/
/* --- Splitter Layout                                                    ---*/
/* --------------------------------------------------------------------------*/

type Layout = {
  hsplit: boolean;
  foldA: boolean;
  foldB: boolean;
};

const PANEL = 'dome-container';
const DRAGGING = 'dome-color-dragging';
const DRAGZONE = 'dome-color-dragzone';

const CONTAINER = 'dome-xSplitter-container';
const NOCURSOR = 'dome-xSplitter-no-cursor';
const HCURSOR = 'dome-xSplitter-h-cursor';
const VCURSOR = 'dome-xSplitter-v-cursor';

const HIDDEN = 'dome-xSplitter-hidden';
const HFLEX = 'dome-xSplitter-hflex';
const VFLEX = 'dome-xSplitter-vflex';

const BLOCK = 'dome-xSplitter-block';
const HPANE = 'dome-xSplitter-hpane';
const VPANE = 'dome-xSplitter-vpane';
const HFOLD = 'dome-xSplitter-hfold';
const VFOLD = 'dome-xSplitter-vfold';
const HLINE = 'dome-xSplitter-hline';
const VLINE = 'dome-xSplitter-vline';
const HANDLE = '.dome-xSplitter-grab';
const HGRAB = 'dome-xSplitter-grab dome-xSplitter-hgrab';
const VGRAB = 'dome-xSplitter-grab dome-xSplitter-vgrab';
const HPOSA = 'dome-xSplitter-hpos-A';
const VPOSA = 'dome-xSplitter-vpos-A';
const HPOSB = 'dome-xSplitter-hpos-B';
const VPOSB = 'dome-xSplitter-vpos-B';
const HPOSR = 'dome-xSplitter-hline dome-xSplitter-hpos-R';
const VPOSR = 'dome-xSplitter-vline dome-xSplitter-vpos-R';

type CSS = {
  container: string;
  sideA: string;
  sideB: string;
  split: string;
};

const getFlexCSS = (hsplit: boolean, fold: boolean): string => (
  hsplit ? (fold ? HFOLD : HPANE) : (fold ? VFOLD : VPANE)
);

const getCSS = (
  unfold: boolean,
  dragged: boolean,
  { hsplit, foldA, foldB }: Layout,
): CSS => {
  // FOLDED
  if (!unfold) return {
    container: BLOCK,
    sideA: foldA ? HIDDEN : BLOCK,
    split: HIDDEN,
    sideB: foldB ? HIDDEN : BLOCK,
  };
  // DRAGGED
  if (dragged) return {
    container: BLOCK,
    sideA: hsplit ? HPOSA : VPOSA,
    split: hsplit ? HPOSR : VPOSR,
    sideB: hsplit ? HPOSB : VPOSB,
  };
  // FLEX
  return {
    container: hsplit ? HFLEX : VFLEX,
    sideA: getFlexCSS(hsplit, foldA),
    split: hsplit ? HLINE : VLINE,
    sideB: getFlexCSS(hsplit, foldB),
  };
};

/* --------------------------------------------------------------------------*/
/* --- Sizing Utility Engine                                              ---*/
/* --------------------------------------------------------------------------*/

type Dragging = undefined | {
  position: number;
  anchor: number;
  offset: number;
};

function getPositionFromSettings(
  dragging: Dragging,
  L: Layout,
  S: number,
  D: number,
): number {
  if (dragging) return dragging.position;
  if (L.foldA) return S;
  if (L.foldB) return D - S;
  return D * S;
}

function getSettingsFromPosition(L: Layout, P: number, D: number): number {
  if (L.foldA) return P;
  if (L.foldB) return D - P;
  return P / D;
}

/**
   Clamp a splitter position to the valid interval for the current layout.

   The returned position must leave enough room on both sides of the splitter:
   - `minA` is the minimum size allowed for side A,
   - `minB` is the minimum size allowed for side B.

   Parameters:
   - `M` is the regular minimum margin kept for a non-collapsed side,
   - `D` is the total available size of the splitter container,
   - `P` is the requested splitter position before clamping.

   For foldable layouts, `allowResizeToZero` lets the foldable side shrink to
   `0` while keeping the opposite side constrained by the regular margin `M`.

   When the container itself is smaller than the sum of both minima, the
   constraints are impossible to satisfy; in that case we fall back to the
   middle of the available space.
 */
function inRange(
  L: Layout,
  allowResizeToZero: boolean,
  M: number,
  D: number,
  P: number,
): number {
  // Compute the minimum size required on each side of the splitter.
  const minA = allowResizeToZero && L.foldA ? 0 : M;
  const minB = allowResizeToZero && L.foldB ? 0 : M;
  const minD = minA + minB;

  // If both minima cannot fit in the container, use a neutral midpoint.
  if (D < minD) return D / 2;

  // Otherwise clamp the requested position inside the feasible interval.
  return Math.min(Math.max(P, minA), D - minB);
}

/* --------------------------------------------------------------------------*/
/* --- Splitter Engine                                                    ---*/
/* --------------------------------------------------------------------------*/

interface SplitterLayoutProps extends SplitterFoldProps { layout: Layout }
interface SplitterEngineProps extends SplitterLayoutProps { size: Size }

function SplitterEngine(props: SplitterEngineProps): JSX.Element {
  const defaultPosition = props.defaultPosition ?? 0;
  const [storedSettings, setStoredSettings] =
    Dome.useNumberSettings(props.settings, defaultPosition);
  const settings = props.position ?? storedSettings;
  const setSettings = props.onPosition ?? setStoredSettings;
  const [dragging, setDragging] = React.useState<Dragging>(undefined);
  const { size, margin = 32, layout } = props;
  const { hsplit } = layout;
  const M = Math.max(margin, 32);
  const D = hsplit ? size.width : size.height;
  const { unfold = true, allowResizeToZero = false } = props;
  const zeroFold = allowResizeToZero && (layout.foldA || layout.foldB);
  const [A, B] = props.children;
  const dragged = (zeroFold ? settings >= 0 : settings > 0) || !!dragging;
  const css = getCSS(unfold, dragged, layout);
  const cursor = dragging ? (hsplit ? HCURSOR : VCURSOR) : NOCURSOR;
  const container = Utils.classes(css.container, cursor);
  const sideA = Utils.classes(css.sideA, PANEL);
  const sideB = Utils.classes(css.sideB, PANEL);
  const dragger = Utils.classes(
    hsplit ? HGRAB : VGRAB,
    dragging ? DRAGGING : DRAGZONE,
  );

  let styleA: undefined | React.CSSProperties;
  let styleB: undefined | React.CSSProperties;
  let styleR: undefined | React.CSSProperties;

  if (unfold && dragged) {
    const P = getPositionFromSettings(dragging, layout, settings, D);
    const X = dragging ? dragging.offset - dragging.anchor : 0;
    const Q = inRange(layout, zeroFold, M, D, P + X);
    styleA = hsplit ? { width: Q } : { height: Q };
    styleR = hsplit ? { left: Q } : { top: Q };
    styleB = hsplit ? { left: Q + 1 } : { top: Q + 1 };
  }

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
        setSettings(defaultPosition);
      } else if (unfold && dragging) {
        const offsetPos = dragging.position + dragging.offset - dragging.anchor;
        const newPos = inRange(layout, zeroFold, M, D, offsetPos);
        setSettings(getSettingsFromPosition(layout, newPos, D));
      }
      setDragging(undefined);
    };

  return (
    <div
      key="container"
      className={container}
      style={props.size}
    >
      <div
        key="sideA"
        className={sideA}
        style={styleA}
      >
        {A}
      </div>
      <DraggableCore
        key="split"
        handle={HANDLE}
        onStart={onStart}
        onDrag={onDrag}
        onStop={onStop}
      >
        <div
          className={css.split}
          style={styleR}
        >
          <div className={dragger} />
        </div>
      </DraggableCore>
      <div
        key="sideB"
        className={sideB}
        style={styleB}
      >
        {B}
      </div>
    </div>
  );
}

const SplitterLayout = (props: SplitterLayoutProps): JSX.Element => (
  <div className={CONTAINER}>
    <AutoSizer>
      {(size: Size) => (
        <SplitterEngine size={size} {...props} />
      )}
    </AutoSizer>
  </div>
);

// --------------------------------------------------------------------------
// --- Short Cuts
// --------------------------------------------------------------------------

const HLayout = { hsplit: true, foldA: false, foldB: false };
const LLayout = { hsplit: true, foldA: true, foldB: false };
const RLayout = { hsplit: true, foldA: false, foldB: true };
const VLayout = { hsplit: false, foldA: false, foldB: false };
const TLayout = { hsplit: false, foldA: true, foldB: false };
const BLayout = { hsplit: false, foldA: false, foldB: true };

const getLayout = (d: Direction): Layout => {
  switch (d) {
    case Direction.HORIZONTAL: return HLayout;
    case Direction.LEFT: return LLayout;
    case Direction.RIGHT: return RLayout;
    case Direction.VERTICAL: return VLayout;
    case Direction.TOP: return TLayout;
    case Direction.BOTTOM: return BLayout;
  }
};

/** Splitter with specified direction.
   @category Base Component
*/
export function Splitter(props: SplitterDirProps): JSX.Element {
  const { direction, ...others } = props;
  const layout = getLayout(direction);
  return <SplitterLayout layout={layout} {...others} />;
}

/** Horizontal Splitter. */
export function HSplit(props: SplitterBaseProps): JSX.Element {
  return <SplitterLayout layout={HLayout} {...props} />;
}

/** Vertical Splitter. */
export function VSplit(props: SplitterBaseProps): JSX.Element {
  return <SplitterLayout layout={VLayout} {...props} />;
}

/** Horizontal Splitter with stacked and foldable left element. */
export function LSplit(props: SplitterFoldProps): JSX.Element {
  return <SplitterLayout layout={LLayout} {...props} />;
}

/** Horizontal Splitter with stacked and foldable right element. */
export function RSplit(props: SplitterFoldProps): JSX.Element {
  return <SplitterLayout layout={RLayout} {...props} />;
}

/** Vertical Splitter with stacked and foldable top element. */
export function TSplit(props: SplitterFoldProps): JSX.Element {
  return <SplitterLayout layout={TLayout} {...props} />;
}

/** Vertical Splitter with stacked and foldable bottom element. */
export function BSplit(props: SplitterFoldProps): JSX.Element {
  return <SplitterLayout layout={BLayout} {...props} />;
}

// --------------------------------------------------------------------------
