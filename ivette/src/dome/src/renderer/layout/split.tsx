// --------------------------------------------------------------------------
// --- Splitters
// --------------------------------------------------------------------------

/**
    @packageDocumentation
    @module dome/layout/split
*/

import _ from 'lodash';
import * as React from 'react';
import * as Dome from 'dome';
import * as Utils from 'dome/misc/utils';
import { DraggableCore, DraggableEventHandler } from 'react-draggable';
import { AutoSizer, Size } from 'react-virtualized';

// --------------------------------------------------------------------------
// --- Splitter
// --------------------------------------------------------------------------

export interface SplitterBaseProps {
  /** Use window settings to store the splitter position */
  settings?: string;
  /** Minimal margin from container edges (minimum 32) */
  margin?: number;
  /** Splitter children components. */
  children: [JSX.Element, JSX.Element];
}

export interface SplitterFoldProps extends SplitterBaseProps {
  /** Visibility of the folder component. */
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
  cssA: string;
  cssB: string;
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
const HGRAB = 'dome-xSplitter-hgrab';
const VGRAB = 'dome-xSplitter-vgrab';

type CSS = {
  container: string;
  primary: string;
  resizer: string;
  secondary: string;
};

const getCSS = (
  unfold: boolean,
  position: number,
  { hsplit, cssA, cssB }: Layout,
): CSS => {
  // FOLDED
  if (!unfold) return {
    container: BLOCK,
    resizer: HIDDEN,
    primary: (cssA === HFOLD || cssA === VFOLD) ? HIDDEN : BLOCK,
    secondary: (cssB === HFOLD || cssB === VFOLD) ? HIDDEN : BLOCK,
  };
  // POSITION
  if (position > 0) return {
    container: BLOCK,
    resizer: hsplit ? HLINE : VLINE,
    primary: BLOCK,
    secondary: BLOCK,
  };
  // FLEX
  return {
    container: hsplit ? HFLEX : VFLEX,
    resizer: hsplit ? HLINE : VLINE,
    primary: cssA,
    secondary: cssB,
  };
};

/* --------------------------------------------------------------------------*/
/* --- Splitter Engine                                                    ---*/
/* --------------------------------------------------------------------------*/

interface SplitterLayoutProps extends SplitterFoldProps {
  layout: Layout;
}

interface SplitterEngineProps extends SplitterLayoutProps {
  size: Size;
}

function SplitterEngine(props: SplitterEngineProps) {
  const [position] = Dome.useNumberSettings(props.settings, 0);
  const [dragging, setDragging] = React.useState(false);
  const { hsplit } = props.layout;
  const dimension = hsplit ? props.size.width : props.size.height;
  const savedim = React.useRef(dimension);
  const { unfold = true } = props;
  const [A, B] = props.children;
  const css = getCSS(unfold, position, props.layout);
  const cursor = dragging ? (hsplit ? HCURSOR : VCURSOR) : NOCURSOR;
  const container = Utils.classes(css.container, cursor);
  const primary = Utils.classes(css.primary, PANEL);
  const secondary = Utils.classes(css.secondary, PANEL);
  const dragger = Utils.classes(
    hsplit ? HGRAB : VGRAB,
    dragging ? DRAGGING : DRAGZONE,
  );

  const onStart: DraggableEventHandler = (_elt, _data) => {
    // const p = hsplit ? data.x : data.y;
    // console.log('START', p);
    setDragging(true);
  };
  const onDrag: DraggableEventHandler = (_elt, _data) => {
    // const p = hsplit ? data.x : data.y;
    // console.log('DRAG', p);
  };
  const onStop: DraggableEventHandler = (_elt, _data) => {
    // const p = hsplit ? data.x : data.y;
    // console.log('STOP', p);
    setDragging(false);
  };

  if (savedim.current !== dimension) {
    // console.log('RESIZED', dimension);
    savedim.current = dimension;
  }

  return (
    <div
      key="container"
      className={container}
      style={props.size}
    >
      <div
        key="primary"
        className={primary}
        style={{}}
      >
        {A}
      </div>
      <div
        key="resizer"
        className={css.resizer}
        style={{}}
      >
        <DraggableCore
          onStart={onStart}
          onDrag={onDrag}
          onStop={onStop}
        >
          <div className={dragger} style={{}} />
        </DraggableCore>
      </div>
      <div
        key="secondary"
        className={secondary}
        style={{}}
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

const HLayout = { hsplit: true, cssA: HPANE, cssB: HPANE };
const LLayout = { hsplit: true, cssA: HFOLD, cssB: HPANE };
const RLayout = { hsplit: true, cssA: HPANE, cssB: HFOLD };
const VLayout = { hsplit: false, cssA: VPANE, cssB: VPANE };
const TLayout = { hsplit: false, cssA: VFOLD, cssB: VPANE };
const BLayout = { hsplit: false, cssA: VPANE, cssB: VFOLD };

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

/** Splitter with specified direction. */
export const Splitter = ({ direction, ...props }: SplitterDirProps) => (
  <SplitterLayout layout={getLayout(direction)} {...props} />
);

const BASE = (L: Layout) => (props: SplitterBaseProps) => (
  <SplitterLayout layout={L} {...props} />
);

const FOLD = (L: Layout) => (props: SplitterFoldProps) => (
  <SplitterLayout layout={L} {...props} />
);

/** Horizontal Splitter. */
export const HSplit = BASE(HLayout);

/** Vertical Splitter. */
export const VSplit = BASE(VLayout);

/** Horizontal Splitter with stacked and foldable top element. */
export const TSplit = FOLD(TLayout);

/** Horizontal Splitter with stacked and foldable bottom element. */
export const BSplit = FOLD(BLayout);

/** Horizontal Splitter with stacked and foldable left element. */
export const LSplit = FOLD(LLayout);

/** Horizontal Splitter with stacked and foldable right element. */
export const RSplit = FOLD(RLayout);

// --------------------------------------------------------------------------
