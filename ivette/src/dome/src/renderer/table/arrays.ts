// --------------------------------------------------------------------------
// --- Array Models
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/table/arrays
*/

import * as Compare from 'dome/data/compare';
import type { ByFields, Order } from 'dome/data/compare';
import {
  Ordering, Sorting, Filter, Filtering, Model, Collection, forEach
} from './models';

// --------------------------------------------------------------------------
// --- Sorting Utilities
// --------------------------------------------------------------------------

interface PACK<Key, Row> {
  index: number | undefined;
  key: Key;
  row: Row;
};

type SORT<K, R> = Order<PACK<K, R>>;

function orderBy<K, R>(fields: ByFields<R>, ord: Ordering): SORT<K, R> {
  const fd = ord.sortBy as keyof R;
  const fn = fields[fd] ?? Compare.equal;
  const rv = ord.sortDirection === 'DESC';
  type D = PACK<K, R>;
  const byField = (x: D, y: D) => fn(x.row[fd], y.row[fd]);
  const byIndex = (x: D, y: D) => (x.index ?? 0) - (y.index ?? 0);
  return Compare.direction(Compare.sequence(byField, byIndex), rv);
}

function orderByRing<K, R>(
  natural: undefined | Order<R>,
  compare: undefined | ByFields<R>,
  ring: Ordering[],
): SORT<K, R> {
  type D = PACK<K, R>;
  const byRing = compare ? ring.map((ord) => orderBy(compare, ord)) : [];
  const byData = natural ? ((x: D, y: D) => natural(x.row, y.row)) : undefined;
  return Compare.sequence(...byRing, byData);
}

// --------------------------------------------------------------------------
// --- Filtering Utilities
// --------------------------------------------------------------------------

type INDEX<K, R> = Map<K, PACK<K, R>>;
type TABLE<K, R> = PACK<K, R>[];

// --------------------------------------------------------------------------
// --- Array Model
// --------------------------------------------------------------------------

export class MapModel<Key, Row>
  extends Model<Key, Row>
  implements Sorting, Filtering<Key, Row>
{

  // Hold raw data (unsorted, unfiltered)
  private index: INDEX<Key, Row> = new Map();

  // Hold filtered & sorted data (computed on demand)
  private table?: TABLE<Key, Row>;

  // Filtering function
  private filter?: Filter<Key, Row>;

  // Natural ordering (if any)
  private natural?: Order<Row>;

  // Sortable columns and associated ordering (if any)
  private columns?: ByFields<Row>;

  // Comparison Ring
  private ring: Ordering[] = [];

  // Consolidated order (computed on demand)
  private order?: SORT<Key, Row>;

  // Lazily compute order
  protected sorter(): SORT<Key, Row> {
    let current = this.order;
    if (current) return current;
    current = this.order = orderByRing(this.natural, this.columns, this.ring);
    return current;
  }

  // Lazily compute table
  protected rebuild(): TABLE<Key, Row> {
    const current = this.table;
    if (current) return current;
    let table: TABLE<Key, Row> = this.table = [];
    this.index.forEach((packed) => {
      const phi = this.filter;
      const ok = phi ? phi(packed.key, packed.row) : true;
      packed.index = ok ? table.push(packed) - 1 : undefined;
    });
    table.sort(this.sorter());
    return table;
  }

  // --------------------------------------------------------------------------
  // --- Proxy
  // --------------------------------------------------------------------------

  getRowCount() { return this.rebuild().length; }

  getRowAt(k: number) { return this.rebuild()[k]?.row; }

  getKeyFor(k: number, _: Row) {
    const current = this.table;
    return current ? current[k].key : undefined;
  }

  getIndexOf(key: Key) {
    const pack = this.index.get(key);
    if (!pack) return undefined;
    const k = pack.index;
    if (k === undefined || k < 0) return undefined;
    const current = this.table;
    return (current && k < current.length) ? k : undefined;
  }

  // --------------------------------------------------------------------------
  // --- Ordering
  // --------------------------------------------------------------------------

  /** Sets comparison functions for (sortable) columns.
      This makes the associated columns sortable in views.
      Finally triggers a reload. */
  setCompare(columns?: ByFields<Row>) {
    this.columns = columns;
    this.reload();
  }

  /** Sets natural ordering function.
      This ordering is always used to finally refine
      column ordering, if any.
      When `undefined`, the natural order follows data insertion order.
      Finally triggers a reload. */
  setNaturalOrder(order?: Order<Row>) {
    this.natural = order;
    this.reload();
  }

  /** Reorder rows with the provided column and direction.
      Previous ordering is kept and refined by the new one.
      Use `undefined` or `null` to reset the natural ordering. */
  setOrdering(ord?: undefined | null | Ordering) {
    if (ord) {
      const ring = this.ring;
      const cur = this.ring[0];
      const fd = ord.sortBy;
      if (
        !cur ||
        cur.sortBy !== fd ||
        cur.sortDirection !== ord.sortDirection
      ) {
        const newRing = ring.filter((o) => o.sortBy !== fd);
        newRing.unshift(ord);
        this.ring = newRing;
        this.reload();
      }
    } else {
      if (this.ring.length > 0) {
        this.ring = [];
        this.reload();
      }
    }
  }

  hasOrdering(column: string) {
    const columns = this.columns as any;
    return columns[column] !== undefined;
  }

  // --------------------------------------------------------------------------
  // --- Filtering
  // --------------------------------------------------------------------------

  setFilter(fn?: Filter<Key, Row>) {
    const phi = this.filter;
    if (phi !== fn) {
      this.filter = fn;
      this.reload();
    }
  }

  // --------------------------------------------------------------------------
  // --- Full Updates
  // --------------------------------------------------------------------------

  /** Trigger a complete reload of the table. */
  reload() {
    if (this.table || this.order) {
      this.table = undefined;
      this.order = undefined;
      super.reload();
    }
  }

  /** Remove all data and reload. */
  clear() {
    this.index.clear();
    this.reload();
  }

  // --------------------------------------------------------------------------
  // --- Checks for Reload vs. Update
  // --------------------------------------------------------------------------

  private needReloadForUpdate(pack: PACK<Key, Row>): boolean {
    // Case where reload is already triggered
    const current = this.table;
    if (!current) return false;
    // Case where filtering of key has changed
    const k = pack.index ?? -1;
    const n = current ? current.length : 0;
    const phi = this.filter;
    const old_ok = 0 <= k && k < n;
    const now_ok = phi ? phi(pack.key, pack.row) : true;
    if (old_ok !== now_ok) return true;
    // Case where element was not displayed and will still not be
    if (!old_ok) return false;
    // Detecting if ordering is preserved
    const order = this.sorter();
    const prev = k - 1;
    if (0 <= prev && order(pack, current[prev]) < 0) return true;
    const next = k + 1;
    if (next < n && order(current[next], pack) < 0) return true;
    super.updateIndex(k);
    return false;
  }

  private needReloadForInsert(pack: PACK<Key, Row>): boolean {
    // Case where reload is already triggered
    const current = this.table;
    if (!current) return false;
    // Case where inserted element is filtered out
    const phi = this.filter;
    return phi ? phi(pack.key, pack.row) : true;
  }

  private needReloadForRemoval(pack: PACK<Key, Row>): boolean {
    // Case where reload is already triggered
    const current = this.table;
    if (!current) return false;
    // Case where inserted element is filtered out
    const k = pack.index ?? -1;
    return 0 <= k && k < current.length;
  }

  // --------------------------------------------------------------------------
  // --- Update item and optimized reload
  // --------------------------------------------------------------------------

  /**
     Update a data entry and signal the views only if needed.
     Use `undefined` to keep value unchanged, `null` for removal,
     or the new row data for update. This triggers a full
     reload if ordering or filtering if modified by the updated value,
     a update index if the row data is only modified and visible.
     Otherwise, no rendering is triggered since the modification
     is not visible.
     @param key - the entry identifier
     @param row - new value of `null` for removal
   */
  update(key: Key, row?: undefined | null | Row) {
    if (row === undefined) return;
    const pack = this.index.get(key);
    let doReload = false;
    if (pack) {
      if (row === null) {
        // Removal
        this.index.delete(key);
        doReload = this.needReloadForRemoval(pack);
      } else {
        // Updated
        pack.row = row;
        doReload = this.needReloadForUpdate(pack);
      }
    } else {
      if (row === null) {
        // Nop
        return;
      } else {
        const newPack = { key, row, index: undefined };
        this.index.set(key, newPack);
        doReload = this.needReloadForInsert(newPack);
      }
    }
    if (doReload) this.reload();
  }

  // --------------------------------------------------------------------------
  // ---  Batched Updates
  // --------------------------------------------------------------------------

  /**
     Silently removes the entry.
     Modification will be only visible after a final [[reload]].
     Useful for a large number of batched updates.
  */
  removeAllData() {
    this.index.clear();
  }

  /**
     Silently removes the entry.
     Modification will be only visible after a final [[reload]].
     Useful for a large number of batched updates.
     @param key - the removed entry.
   */
  removeData(key: Key) {
    this.index.delete(key);
  }

  /**
     Silently updates the entry.
     Modification will be only visible after a final [[reload]].
     Useful for a large number of batched updates.
     @param key - the entry to update.
     @param row - the new row data or `null` for removal.
   */
  setData(key: Key, row: null | Row) {
    if (row !== null) {
      this.index.set(key, { key, row, index: undefined });
    } else {
      this.index.delete(key);
    }
  }

  /** Returns the data associated with a key (if any). */
  getData(key: Key): Row | undefined {
    return this.index.get(key)?.row;
  }

}

// --------------------------------------------------------------------------
// --- Compact Array Model
// --------------------------------------------------------------------------

export class ArrayModel<Row> extends MapModel<string, Row> {

  private key: keyof Row

  constructor(key: keyof Row) {
    super();
    this.key = key;
  }

  /** Returns the key of data. */
  getKey(data: Row): string { return (data as any)[this.key]; }

  /** Adds a collection of data. Finally triggers a reload. */
  add(data: Collection<Row>) {
    forEach(data, (row: Row) => this.setData(this.getKey(row), row));
    this.reload();
  }

  /** Replaces all previous entries with new ones. Finally triggers a reload. */
  replace(data: Collection<Row>) {
    this.removeAllData();
    this.add(data);
  }

  /** Removes a colllection of data, identified by keys or (key of) rows.
      Finally triggers a reload. */
  remove(data: Collection<string | Row>) {
    forEach(data, e => {
      const k = typeof e === 'string' ? e : this.getKey(e);
      this.removeData(k);
    });
    this.reload();
  }

}

// --------------------------------------------------------------------------
