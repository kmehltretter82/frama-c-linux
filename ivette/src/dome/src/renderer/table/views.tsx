// --------------------------------------------------------------------------
// --- Tables
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/table/views
 */

import React from 'react';
import { debounce } from 'lodash';
import isEqual from 'react-fast-compare';
//import * as Dome from 'dome';
import { Trigger, Client, Sorting, Model } from './models';
//import { DraggableCore, DraggableEventHandler } from 'react-draggable';
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
  RowMouseEventHandlerParams,
} from 'react-virtualized';

import './style.css';

const SVG = SVGraw as (props: { id: string, size?: number }) => JSX.Element;

// --------------------------------------------------------------------------
// --- Rendering Interfaces
// --------------------------------------------------------------------------

export type Renderer<D> = (data?: D) => null | JSX.Element;
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
  /** Selection callback. */
  onSelection?: (row: Row, key: Key, index: number) => void;
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
  const defaultVisible = col.visible ?? true;
  switch (defaultVisible) {
    case 'never': return false;
    case 'always': return false;
    default:
      return visible.get(col.id) ?? defaultVisible;
  }
};

function makeGetter<Key, Row>(model?: Model<Key, Row>) {
  return ({ index }: Index) => model && model.getRowAt(index);
};

// --------------------------------------------------------------------------
// --- Table State
// --------------------------------------------------------------------------

class TableState<Key, Row> {

  signal?: Trigger; // Full reload
  resize: Cmap<number> = new Map(); // Current
  visible: Cmap<boolean> = new Map(); // Current
  headerRef: Cmap<divRef> = new Map(); // Once, build on demand
  tableRef: tableRef = React.createRef(); // Once, global
  getter: Cmap<TableCellDataGetter> = new Map(); // Computed from registry
  render: Cmap<TableCellRenderer> = new Map(); // Computed from registry and getterFields
  rowGetter: (info: Index) => Row | undefined; // Computed from last fetching
  fields?: RenderByFields<Row>; // Last user props used for computing renderers
  model?: Model<Key, Row>; // Last user proxy used for computing getter
  sorting?: Sorting; // Last user proxy used for sorting
  client?: Client; // Client of last fetching
  columns: ColProps<Row>[] = []; // Currently known columns
  selectedKey?: Key; // Last selected key
  selectedIndex?: number; // Current selected index

  constructor() {
    this.reload = this.reload.bind(this);
    this.update = this.update.bind(this);
    this.watchRange = this.watchRange.bind(this);
    this.rowClassName = this.rowClassName.bind(this);
    this.contextMenu = this.contextMenu.bind(this);
    this.onRowClick = this.onRowClick.bind(this);
    this.rebuild = debounce(this.rebuild.bind(this), 50);
    this.rowGetter = makeGetter();
  }

  // --- Static Callbacks

  reload() {
    const s = this.signal;
    if (s) {
      this.signal = undefined; s();
      this.update();
    }
  }

  update() {
    this.tableRef.current?.forceUpdateGrid();
  }

  getRef(id: string) {
    const href = this.headerRef.get(id);
    if (href) return href;
    const nref: divRef = React.createRef();
    this.headerRef.set(id, nref);
    return nref;
  }

  // --- User Table properties

  setSorting(sorting?: Sorting) {
    if (sorting !== this.sorting) {
      this.sorting = sorting;
      this.reload();
    }
  }

  setModel(model?: Model<Key, Row>) {
    if (model !== this.model) {
      this.client?.unlink();
      this.model = model;
      if (model) {
        const client = model.link();
        client.onReload(this.reload);
        client.onUpdate(this.update);
        this.client = client;
      } else {
        this.client = undefined;
      }
      this.rowGetter = makeGetter(model);
      this.reload();
    }
  }

  setRendering(fields?: RenderByFields<Row>) {
    if (fields !== this.fields) {
      this.fields = fields;
      this.render.clear();
      this.reload();
    }
  }

  // ---- Selection Management

  onSelection?: (data: Row, key: Key, index: number) => void;

  onRowClick(info: RowMouseEventHandlerParams) {
    const index = info.index;
    const data = info.rowData as (Row | undefined);
    const model = this.model;
    const key = (data !== undefined) ? model?.getKeyFor(index, data) : undefined;
    const onSelection = this.onSelection;
    if (key !== undefined && data !== undefined && onSelection)
      onSelection(data, key, index);
  }

  watchRange(info: IndexRange) {
    this.client?.watch(info.startIndex, info.stopIndex);
  }

  rowClassName({ index }: Index): string {
    if (this.selectedIndex === index) return 'dome-xTable-selected';
    return (index & 1 ? 'dome-xTable-even' : 'dome-xTable-odd');
  }

  scrollToIndex(selection: Key | undefined): number | undefined {
    const index = selection && this.model?.getIndexOf(selection);
    this.selectedIndex = index;
    if (this.selectedKey !== selection) {
      this.selectedKey = selection;
      if (selection) return index;
    }
    return undefined;
  }

  // ---- Context Menu

  contextMenu() {
    console.log('CONTEXT MENU');
  }

  // --- User Column Registry

  private registry = new Map<string, null | ColProps<Row>>();

  setRegistry(id: string, props: null | ColProps<Row>) {
    this.registry.set(id, props);
    this.rebuild();
  }

  useColumn(props: ColProps<Row>): Trigger {
    const id = props.id;
    this.setRegistry(id, props);
    return () => this.setRegistry(id, null);
  }

  rebuild() {
    const current = this.columns;
    const cols: ColProps<Row>[] = [];
    this.registry.forEach((col) => col && cols.push(col));
    if (!isEqual(current, cols)) {
      this.getter.clear();
      this.render.clear();
      this.columns = cols;
      this.reload();
    }
  }
}

// --------------------------------------------------------------------------
// --- Columns Components
// --------------------------------------------------------------------------

const ColumnContext =
  React.createContext<undefined | TableState<any, any>>(undefined);

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

function makeColumn<Key, Row>(
  state: TableState<Key, Row>,
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

function makeColumns<Key, Row>(state: TableState<Key, Row>) {
  const cols: Cprops[] = [];
  let hasFill = false;
  let lastExt: undefined | Cprops;
  state.columns.forEach((col) => {
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
// --- Table Utility Renderers
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
// --- Virtualized Table View
// --------------------------------------------------------------------------

// Must be kept in sync with table.css
const CSS_HEADER_HEIGHT = 22;
const CSS_ROW_HEIGHT = 20;

function makeTable<Key, Row>(
  size: Size,
  props: TableProps<Key, Row>,
  state: TableState<Key, Row>,
) {
  const { width, height } = size;
  const model = props.model;
  const itemCount = model.getRowCount();
  const tableHeight = CSS_HEADER_HEIGHT + CSS_ROW_HEIGHT * itemCount;
  const smallHeight = itemCount > 0 && tableHeight < height;
  const rowCount = (smallHeight ? itemCount + 1 : itemCount);
  const scrollTo = state.scrollToIndex(props.selection);
  const columns = makeColumns(state);
  return (
    <React.Fragment>
      <VTable
        ref={state.tableRef}
        key="table"
        displayName="React-Virtualized-Table"
        width={width}
        height={height}
        rowCount={rowCount}
        noRowsRenderer={props.renderEmpty}
        rowGetter={state.rowGetter}
        rowClassName={state.rowClassName}
        rowHeight={CSS_ROW_HEIGHT}
        headerHeight={CSS_HEADER_HEIGHT}
        headerRowRenderer={headerRowRenderer}
        onRowsRendered={state.watchRange}
        onRowClick={state.onRowClick}
        sortBy={undefined}
        sortDirection={undefined}
        sort={undefined}
        scrollToIndex={scrollTo}
        scrollToAlignment="auto"
      >
        {columns}
      </VTable>
      {/*resizers*/null}
    </React.Fragment>
  );
};

// --------------------------------------------------------------------------
// --- Table View
// --------------------------------------------------------------------------

/**
   Table View.

   This component is base on [React-Virtualized
   Tables](https://bvaughn.github.io/react-virtualized/#/components/Table),
   offering a lazy, super-optimized rendering process that scales on huge
   datasets.

   A table shall be connected to an instance of
   [[Model]] class to retrieve the data and
   get informed of data updates.

   The table columns shall be instances of
   [[Column]] class.

   Clicking on table headers trigger re-ordering callback on the model with the
   expected column and direction, unless disabled _via_ the column
   x   specification. However, actual sorting (and corresponding feedback on table
   headers) would only take place if the model supports re-ordering and
   eventually triggers a reload.

   Right-clicking the table headers displays a popup-menu with actions to reset natural ordering,
   reset column widths and select column visibility.

   Tables do not control item selection state. Instead, you shall supply the selection
   state and callback _via_ properties, like any other controlled React components.

   Item selection can be based either on single-row or multiple-row. In case of
   single-row selection (`multipleSelection:false`, the default), selection state
   must be a single item or `undefined`, and the `onSelection` callback is called
   with the same type of values.

   In case of multiple-row selection (`multipleSelection:true`), the selection state
   shall be an _array_ of items, and `onSelection` callback also. Single items are _not_
   accepted, but `undefined` selection can be used in place of an empty array.

   Clicking on a row triggers the `onSelection` callback with the updated selection.
   In single-selection mode, the clicked item is sent to the callback. In
   multiple-selection mode, key modifiers are taken into account for determining the new
   slection. By default, the new selection only contains the clicked item. If the `Shift`
   modifier has been pressed, the current selection is extended with a range of items
   from the last selected one, to the newly selected one. If the `CtrlOrCmd` modifier
   has been pressed, the selection is extended with the newly clicked item.
   Clicking an already selected item with the `CtrlOrCmd` modifier removes it from
   the current selection.

 */

export function Table<Key, Row>(props: TableProps<Key, Row>) {

  const state = React.useMemo(() => new TableState<Key, Row>(), []);
  const [age, setAge] = React.useState(0);
  React.useEffect(() => {
    state.signal = () => setAge(age + 1);
    state.setModel(props.model);
    state.setSorting(props.sorting);
    state.setRendering(props.rendering);
    state.onSelection = props.onSelection;
  });

  return (
    <div className='dome-xTable'>
      <ColumnContext.Provider value={state}>
        {props.children}
      </ColumnContext.Provider>
      <AutoSizer key='table'>
        {(size: Size) => makeTable(size, props, state)}
      </AutoSizer>
    </div>
  );
}

// --------------------------------------------------------------------------
