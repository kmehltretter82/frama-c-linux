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
import { AutoSizer, Size } from 'react-virtualized';

// --------------------------------------------------------------------------
// --- Splitter
// --------------------------------------------------------------------------

export interface SplitterBaseProps {
  /** Window settings to store the splitter position. */
  settings?: string;
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

const getFlexCSS = (hsplit: boolean, fold: boolean) => (
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
/* --- Splitter Engine                                                    ---*/
/* --------------------------------------------------------------------------*/

interface SplitterLayoutProps extends SplitterFoldProps { layout: Layout }
interface SplitterEngineProps extends SplitterLayoutProps { size: Size }

type Dragging = undefined | {
  position: number;
  anchor: number;
  offset: number;
};

const getResized = (layout: Layout, D0: number, D: number, P: number) => {
  if (layout.foldA) return P;
  if (layout.foldB) return P + D - D0;
  if (D0 > 0) return Math.round(P * (D / D0));
  return P;
};

const inRange = (M: number, D: number, P: number) => (
  D < M ? D / 2 : Math.min(Math.max(P, M), D - M)
);

function SplitterEngine(props: SplitterEngineProps) {
  const [position, setPosition] = Dome.useNumberSettings(props.settings, 0);
  const [dragging, setDragging] = React.useState<Dragging>(undefined);
  const { size, margin = 32, layout } = props;
  const { hsplit } = layout;
  const M = Math.max(margin, 32);
  const D = hsplit ? size.width : size.height;
  const savedim = React.useRef(D);
  const { unfold = true } = props;
  const [A, B] = props.children;
  const dragged = position > 0 || dragging !== undefined;
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

  if (dragged) {
    const P = dragging ? dragging.position : position;
    const X = dragging ? dragging.offset - dragging.anchor : 0;
    const Q = inRange(M, D, P + X);
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
        setPosition(0);
      } else if (dragging) {
        const newPos = dragging.position + dragging.offset - dragging.anchor;
        setPosition(inRange(M, D, newPos));
      }
      setDragging(undefined);
    };

  if (savedim.current !== D) {
    const D0 = savedim.current;
    savedim.current = D;
    if (position > 0 && !dragging) {
      const newPos = getResized(layout, D0, D, position);
      setPosition(inRange(M, D, newPos));
    }
  }

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
        handle={HANDLE}
        onStart={onStart}
        onDrag={onDrag}
        onStop={onStop}
      >
        <div
          key="split"
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

const SplitterLayout = (props: SplitterLayoutProps) => (
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
export function Splitter(props: SplitterDirProps) {
  const { direction, ...others } = props;
  const layout = getLayout(direction);
  return <SplitterLayout layout={layout} {...others} />;
}

/** Horizontal Splitter. */
export function HSplit(props: SplitterBaseProps) {
  return <SplitterLayout layout={HLayout} {...props} />;
}

/** Vertical Splitter. */
export function VSplit(props: SplitterBaseProps) {
  return <SplitterLayout layout={VLayout} {...props} />;
}

/** Horizontal Splitter with stacked and foldable left element. */
export function LSplit(props: SplitterFoldProps) {
  return <SplitterLayout layout={LLayout} {...props} />;
}

/** Horizontal Splitter with stacked and foldable right element. */
export function RSplit(props: SplitterFoldProps) {
  return <SplitterLayout layout={RLayout} {...props} />;
}

/** Vertical Splitter with stacked and foldable top element. */
export function TSplit(props: SplitterFoldProps) {
  return <SplitterLayout layout={TLayout} {...props} />;
}

/** Vertical Splitter with stacked and foldable bottom element. */
export function BSplit(props: SplitterFoldProps) {
  return <SplitterLayout layout={BLayout} {...props} />;
}

// --------------------------------------------------------------------------
