// --------------------------------------------------------------------------
// --- Tables
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/table/views
 */

import React from 'react';
import * as Dome from 'dome';
import { Trigger, Client, Sorting, Fetching, Model } from './models';
import { DraggableCore, DraggableEventHandler } from 'react-draggable';
import { SVG as SVGraw } from 'dome/controls/icons';
import {
  AutoSizer, Size,
  SortDirection, Index, IndexRange,
  Table as VTable,
  Column as VColumn,
  TableHeaderRowProps,
  TableHeaderProps,
  TableCellDataGetter,
  TableCellRenderer,
} from 'react-virtualized';

import './style.css';

const SVG = SVGraw as (props: { id: string, size?: number }) => JSX.Element;

// --------------------------------------------------------------------------
// --- Rendering Interfaces
// --------------------------------------------------------------------------

export type Renderer<D> = (data: D) => null | JSX.Element;
export type RenderByFields<Row> = {
  [fd in keyof Row]?: Renderer<Row[fd]>;
};

const defaultRenderer = (d: any) => {
  switch (d) {
    case null:
    case undefined:
      return null;
    default:
      return <span>{new String(d)}</span>
  }
};

// --------------------------------------------------------------------------
// --- Table Columns
// --------------------------------------------------------------------------

/** Applied to any table cell in a column. */
export type TextAlign = 'left' | 'center' | 'right';

export type Visibility = boolean | 'never' | 'always';

export interface ColumnProps<Row, Data> {
  /** Column identifier. */
  id: string;
  /** Header icon. */
  icon?: string;
  /** Header label. */
  label?: string;
  /** Header title. */
  title?: string;
  /** CSS vertical alignment on cells. */
  align?: TextAlign;
  /** Column base width in pixels (default 60px). */
  width?: number;
  /** Extensible column (not by default). */
  fill?: boolean;
  /** Fixed width column (not by default). */
  fixed?: boolean;
  /**
     Data Key for this column. Defaults to `id`. It is used for:
     - triggering ordering events to the model, if enabled.
     - using by-fields table renderers, if provided.
   */
  dataKey?: string;
  /**
     Disable model sorting, even if enabled by the model
     for this column `dataKey`. Not by default.
   */
  disableSort?: boolean;
  /**
     Default column visibility. With `'never'` or `'always'` the column
     visibility is forced and can not be modified by the user. Otherwize,
     the user can change visibility through the column header context menu.
   */
  visible?: Visibility;
  /**
     Data getter for this column.
   */
  getter?: (row: Row, dataKey: string) => Data;
  /**
     Override table by-fields cell renderers.
   */
  render?: Renderer<Data>;
}

// --------------------------------------------------------------------------
// --- Table Properties
// --------------------------------------------------------------------------

export interface TableProps<Key, Row> {
  /** Data proxy. */
  model: Model<Key, Row>;
  /** Sorting Proxy. */
  sorting?: Sorting;
  /** Rendering by Fields. */
  rendering?: RenderByFields<Row>;
  /** Window settings to store the size and visibility of columns. */
  settings?: string;
  /** Selected row (identified by key). */
  selection?: Key;
  /** Selection callback (identified by key). */
  onSelection?: (selected?: Key) => void;
  /** Ensures the item is visible (if displayed at all). */
  scrollTo?: Key;
  /** Fallback for rendering an empty table. */
  renderEmpty?: () => null | JSX.Element;
  /** Shall only contains `<Column<Row> … />` elements. */
  children?: any;
}

// --------------------------------------------------------------------------
// --- React-Virtualized Interfaces
// --------------------------------------------------------------------------

type divRef = React.RefObject<HTMLDivElement>;
type tableRef = React.RefObject<VTable>;

interface ColumnData {
  icon?: string;
  label?: string;
  title?: string;
  contextMenu: () => void;
  headerRef: divRef;
};

// --------------------------------------------------------------------------
// --- Column Utilities
// --------------------------------------------------------------------------

type Cmap<A> = Map<string, A>
type Cprops = ColProps<any>;
type ColProps<R> = ColumnProps<R, any>;

const isVisible = (visible: Cmap<boolean>, col: Cprops) => {
  const defaultVisible = col.visible;
  switch (defaultVisible) {
    case 'never': return false;
    case 'always': return false;
    default:
      return visible.get(col.id) ?? defaultVisible;
  }
};

function makeGetter<Row>(fetching?: Fetching<Row>) {
  return ({ index }: Index) => fetching && fetching.getRowAt(index);
};

// --------------------------------------------------------------------------
// --- Table State
// --------------------------------------------------------------------------

class TableState<Row> {

  signal?: Trigger; // Full reload
  resize: Cmap<number> = new Map(); // Current
  visible: Cmap<boolean> = new Map(); // Current
  headerRef: Cmap<divRef> = new Map(); // Once, build on demand
  tableRef: tableRef = React.createRef(); // Once, global
  getter: Cmap<TableCellDataGetter> = new Map(); // Computed from registry
  render: Cmap<TableCellRenderer> = new Map(); // Computed from registry and getterFields
  rowGetter: (info: Index) => Row | undefined; // Computed from last fetching
  fields?: RenderByFields<Row>; // Last user props used for computing renderers
  fetching?: Fetching<Row>; // Last user proxy used for computing getter
  sorting?: Sorting; // Last user proxy used for sorting
  client?: Client; // Client of last fetching

  constructor() {
    this.reload = this.reload.bind(this);
    this.update = this.update.bind(this);
    this.contextMenu = this.contextMenu.bind(this);
    this.rowGetter = makeGetter();
  }

  // --- Static Callbacks

  reload() {
    const s = this.signal;
    if (s) { this.signal = undefined; s(); }
  }

  update() {
    this.tableRef.current?.forceUpdateGrid();
  }

  watchRange(info: IndexRange) {
    this.client?.watch(info.startIndex, info.stopIndex);
  }

  getRef(id: string) {
    const href = this.headerRef.get(id);
    if (href) return href;
    const nref: divRef = React.createRef();
    this.headerRef.set(id, nref);
    return nref;
  }

  // --- User Table properties

  setSorting(sorting: Sorting) {
    if (sorting !== this.sorting) {
      this.sorting = sorting;
      this.reload();
    }
  }

  setFetching(fetching: Fetching<Row>) {
    if (fetching !== this.fetching) {
      this.client?.unlink();
      this.fetching = fetching;
      if (fetching) {
        const client = fetching.link();
        client.onReload(this.reload);
        client.onUpdate(this.update);
        this.client = client;
      } else {
        this.client = undefined;
      }
      this.rowGetter = makeGetter(fetching);
      this.reload();
    }
  }

  setRendering(fields: RenderByFields<Row>) {
    if (fields !== this.fields) {
      this.fields = fields;
      this.render.clear();
      this.reload();
    }
  }

  // ---- Context Menu

  contextMenu() {
    console.log('CONTEXT MENU');
  }

  // --- User Column Registry

  private registered?: ColProps<Row>[];
  private registry = new Map<string, null | ColProps<Row>>();

  setRegistry(id: string, props: null | ColProps<Row>) {
    this.registry.set(id, props);
    this.registered = undefined;
    this.getter.delete(id);
    this.render.delete(id);
    this.reload();
  }

  useColumn(props: ColProps<Row>): Trigger {
    const id = props.id;
    this.setRegistry(id, props);
    return () => this.setRegistry(id, null);
  }

  getRegistry() {
    let current = this.registered;
    if (current) return current;
    const cols: ColProps<Row>[] = [];
    this.registry.forEach((col) => col && cols.push(col));
    return cols;
  }

}

// --------------------------------------------------------------------------
// --- Columns Components
// --------------------------------------------------------------------------

const ColumnContext =
  React.createContext<undefined | TableState<any>>(undefined);

/**
   Table Column.
 */
export function Column<Row, Data>(props: ColumnProps<Row, Data>) {
  const context = React.useContext(ColumnContext);
  React.useEffect(() => context && context.useColumn(props));
  return null;
}

// --------------------------------------------------------------------------
// --- Virtualized Column
// --------------------------------------------------------------------------

function makeDataGetter(
  getter: ((row: any, dataKey: string) => any),
  dataKey: string,
): TableCellDataGetter {
  return (({ rowData }) => getter(rowData, dataKey));
}

function makeDataRenderer(
  render: ((data: any) => React.ReactNode)
): TableCellRenderer {
  return (({ cellData }) => render(cellData));
}

function makeColumn<Row>(
  state: TableState<Row>,
  props: ColProps<Row>,
  forceFill: boolean,
) {
  const { id } = props;
  const align = { textAlign: props.align };
  const dataKey = props.dataKey ?? id;
  const columnData: ColumnData = {
    icon: props.icon,
    label: props.label,
    title: props.title,
    contextMenu: state.contextMenu,
    headerRef: state.getRef(id),
  };
  const width = state.resize.get(id) || props.width || 60;
  const flexGrow = (forceFill || props.fill) ? 1 : 0;
  const sorting = state.sorting;
  const disableSort = props.disableSort || !sorting || !sorting.hasOrdering(dataKey);
  let getter: TableCellDataGetter;
  {
    const g = state.getter.get(id);
    if (g) getter = g; else {
      const gc = props.getter ?? ((row: any) => row[dataKey]);
      getter = makeDataGetter(gc, dataKey);
      state.getter.set(id, getter);
    }
  }
  let render: TableCellRenderer;
  {
    const r = state.render.get(id);
    if (r) render = r; else {
      const rc = props.render ?? (state.fields as any)[dataKey];
      render = makeDataRenderer(rc ?? defaultRenderer);
      state.render.set(id, render);
    }
  }
  return (
    <VColumn
      key={id}
      width={width}
      flexGrow={flexGrow}
      dataKey={dataKey}
      columnData={columnData}
      headerRenderer={headerRenderer}
      cellDataGetter={getter}
      cellRenderer={render}
      headerStyle={align}
      disableSort={disableSort}
      style={align}
    />
  );
};

function makeColumns<Row>(state: TableState<Row>) {
  const cols: Cprops[] = [];
  let hasFill = false;
  let lastExt: undefined | Cprops;
  state.getRegistry().forEach((col) => {
    if (col && isVisible(state.visible, col)) {
      cols.push(col);
      if (col.fill) hasFill = true;
      else if (!col.fixed) lastExt = col;
    }
  });
  const n = cols.length;
  if (0 < n && !hasFill && !lastExt) lastExt = cols[n - 1];
  return cols.map((col) => makeColumn(state, col, col === lastExt));
}

// --------------------------------------------------------------------------
// --- Header Renderer
// --------------------------------------------------------------------------

const headerIcon = (icon?: string) => (
  icon &&
  (<div className='dome-xTable-header-icon'>
    <SVG id={icon} />
  </div>)
);

const headerLabel = (label?: string) => (
  label &&
  (<label className='dome-xTable-header-label dome-text-label'>
    {label}
  </label>)
);

const makeSorter = (id: string) => (
  <div className='dome-xTable-header-sorter'>
    <SVG id={id} size={8} />
  </div>
);

const sorterASC = makeSorter('ANGLE.UP');
const sorterDESC = makeSorter('ANGLE.DOWN');

function headerRowRenderer(props: TableHeaderRowProps) {
  return (
    <div
      role="row"
      className={props.className}
      style={props.style}
    >
      {props.columns}
    </div>
  );
}

function headerRenderer(props: TableHeaderProps) {
  const { sortBy, sortDirection, dataKey } = props;
  const data: ColumnData = props.columnData;
  const { icon, label, title, headerRef, contextMenu } = data;
  const sorter =
    dataKey === sortBy
      ? (sortDirection === SortDirection.ASC ? sorterASC : sorterDESC)
      : undefined;
  return (
    <div
      className='dome-xTable-header'
      title={title}
      ref={headerRef}
      onContextMenu={contextMenu}
    >
      {headerIcon(icon)}
      {headerLabel(label)}
      {sorter}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Rows
// --------------------------------------------------------------------------

const rowClassName =
  (selected?: number) =>
    ({ index }: { index: number }) =>
      (selected === index ? 'dome-color-selected' :
        (index & 1 ? 'dome-xTable-even' : 'dome-xTable-odd'));

// --------------------------------------------------------------------------
// --- Column Resizer
// --------------------------------------------------------------------------

const DRAGGING = 'dome-xTable-resizer dome-color-dragging';
const DRAGZONE = 'dome-xTable-resizer dome-color-dragzone';

interface ResizerProps {
  id: number;
  dragging: undefined | number;
  left: string; // resized column-id on the left
  right: string; // resized column-id on the right
  offset: number; // drag-start offset
  onStart: DraggableEventHandler;
  onStop: DraggableEventHandler;
  onDrag: (left: string, right: string, offset: number) => void;
}

const Resizer = (props: ResizerProps) => (
  <DraggableCore
    onStart={props.onStart}
    onStop={props.onStop}
    onDrag={(_elt, data) => props.onDrag(props.left, props.right, data.x - props.offset)}
  >
    <div
      className={props.id === props.dragging ? DRAGGING : DRAGZONE}
      style={{ left: props.offset - 2 }}
    />
  </DraggableCore>
);

const computeWidth = (elt: Element) => {
  const parent = elt && elt.parentElement;
  return parent && parent.getBoundingClientRect().width;
};

// --------------------------------------------------------------------------
// --- Virtualized Table View
// --------------------------------------------------------------------------

// Must be kept in sync with table.css
const CSS_HEADER_HEIGHT = 22;
const CSS_ROW_HEIGHT = 20;

function makeTable<Key, Row>(
  size: Size,
  props: TableProps<Key, Row>,
  state: TableState<Row>,
) {
  const { width, height } = size;
  const model = props.model;
  const itemCount = model.getRowCount();
  const tableHeight = CSS_HEADER_HEIGHT + CSS_ROW_HEIGHT * itemCount;
  const smallHeight = itemCount > 0 && tableHeight < height;
  const rowCount = (smallHeight ? itemCount + 1 : itemCount);
  const selection = props.selection;
  const selected = selection && model.getIndexOf(selection);
  const resizers = null; // this.computeResizers(columns);
  const columns = makeColumns(state);
  return (
    <React.Fragment>
      <VTable
        ref={state.tableRef}
        key='table'
        displayName='React-Virtualized-Table'
        width={width}
        height={height}
        rowCount={rowCount}
        noRowsRenderer={props.renderEmpty}
        rowGetter={state.rowGetter}
        rowClassName={rowClassName(selected)}
        rowHeight={CSS_ROW_HEIGHT}
        headerHeight={CSS_HEADER_HEIGHT}
        headerRowRenderer={headerRowRenderer}
        onRowsRendered={state.watchRange}
        onRowClick={onSelection && this.selectRow}
        sortBy={ordering && ordering.sortBy}
        sortDirection={ordering && ordering.sortDirection}
        sort={model.setOrdering.bind(model)}
        scrollToIndex={scrollToIndex}
        scrollToAlignment='auto'
      >
        {columns}
      </VTable>
      {resizers}
    </React.Fragment>
  );
};

// --------------------------------------------------------------------------
