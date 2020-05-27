// --------------------------------------------------------------------------
// --- Array Models
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/table/arrays
*/

import * as Compare from 'dome/data/compare';
import type { ByFields, Order } from 'dome/data/compare';
import { Ordering, Sorting, Filter, Filtering, Model } from './models';

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

function orderByRing<K, R>(fields: ByFields<R>, ring: Ordering[]): SORT<K, R> {
  return Compare.sequence(...ring.map((ord) => orderBy(fields, ord)));
}

// --------------------------------------------------------------------------
// --- Filtering Utilities
// --------------------------------------------------------------------------

type INDEX<K, R> = Map<K, PACK<K, R>>;
type TABLE<K, R> = PACK<K, R>[];

// --------------------------------------------------------------------------
// --- Collection Utilities
// --------------------------------------------------------------------------

export type Collection<A> = undefined | A | A[];

// --------------------------------------------------------------------------
// --- Array Model
// --------------------------------------------------------------------------

export class ArrayModel<Key, Row>
  extends Model<Key, Row>
  implements Sorting, Filtering<Key, Row>
{

  private order: ByFields<Row>;
  private index: INDEX<Key, Row> = new Map();
  private table: TABLE<Key, Row> | undefined;
  private ring: Ordering[] = [];
  private filter: Filter<Key, Row> | undefined;

  constructor(order?: ByFields<Row>) {
    super();
    this.order = order ?? {};
  }

  // Compute order
  protected ordering(): SORT<Key, Row> { return orderByRing(this.order, this.ring); }

  // Lazy rebuild
  protected rebuild(): TABLE<Key, Row> {
    const current = this.table;
    if (current) return current;
    let table: TABLE<Key, Row> = this.table = [];
    this.index.forEach((packed) => {
      const phi = this.filter;
      const ok = phi ? phi(packed.key, packed.row) : true;
      packed.index = ok ? table.push(packed) - 1 : undefined;
    });
    if (0 < this.ring.length)
      table.sort(this.ordering());
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
    if (k === undefined || 0 < k) return undefined;
    const current = this.table;
    return (current && k < current.length) ? k : undefined;
  }

  // --------------------------------------------------------------------------
  // --- Ordering
  // --------------------------------------------------------------------------

  setOrdering(ord?: Ordering) {
    if (ord) {
      const cur = this.ring[0];
      const fd = ord.sortBy;
      if (
        !cur ||
        cur.sortBy !== fd ||
        cur.sortDirection !== ord.sortDirection
      ) {
        const rg = this.ring.filter((o) => o.sortBy !== fd);
        rg.unshift(ord);
        this.ring = rg;
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
    return this.order[column as keyof Row] !== undefined;
  }

  // --------------------------------------------------------------------------
  // --- Filtering
  // --------------------------------------------------------------------------

  setFiltering(fn?: Filter<Key, Row>) {
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
    if (!this.table) {
      this.table = undefined;
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
    const order = this.ordering();
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

}

// --------------------------------------------------------------------------
