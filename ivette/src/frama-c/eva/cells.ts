// --------------------------------------------------------------------------
// --- Cell Utilities & Value Cache
// --------------------------------------------------------------------------

export type callback = () => void;

export interface StateCallbacks {
  forceUpdate: callback;
  forceLayout: callback;
}

export interface Size { cols: number; rows: number }

export const LABEL = 12; /* number of chars for labels */
export const EMPTY: Size = { cols: 0, rows: 0 };

export function sizeof(text?: string): Size {
  if (!text) return EMPTY;
  const lines = text.split('\n');
  return {
    rows: lines.length,
    cols: lines.reduce((w, l) => Math.max(w, l.length), 0),
  };
}

export function merge(a: Size, b: Size): Size {
  return {
    cols: Math.max(a.cols, b.cols),
    rows: Math.max(a.rows, b.rows),
  };
}

export function addH(a: Size, b: Size, padding = 0): Size {
  return {
    cols: a.cols + b.cols + padding,
    rows: Math.max(a.rows, b.rows),
  };
}

export function addV(a: Size, b: Size, padding = 0): Size {
  return {
    cols: Math.max(a.cols, b.cols),
    rows: a.rows + b.rows + padding,
  };
}

// --------------------------------------------------------------------------
