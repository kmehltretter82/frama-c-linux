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
  TableCellProps,
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
