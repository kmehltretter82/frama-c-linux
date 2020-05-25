// --------------------------------------------------------------------------
// --- Models
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/table/models
*/

import _ from 'lodash';

// --------------------------------------------------------------------------
// --- Sorting
// --------------------------------------------------------------------------

/** @internal */
type ClientId = string;

/** @internal */
interface Client {
  lower: number,
  upper: number,
  trigger: () => void,
};

// --------------------------------------------------------------------------
// --- Collection Model
// --------------------------------------------------------------------------

/**
   A Model is responsible for keeping the tables and lists views in sync
   with their associated data sets. The model listens for updates, retrieves
   items from their index, and re-render the views when necessary.

   Several tables may connect to the same table model, but they will share the
   same number and ordering of items. However, each connected table will only
   render its own range of items and will re-render only when impacted by
   individual updates.

   A Model instance may not hold the data directly. A table or list component
   uses the model only as a _proxy_ reponsible for fetching the items with respect to
   some current filtering and ordering selection. The model also serves as
   a proxy for triggering table re-rendering when table data is updated.

   To design your data model, you shall extends the base `Model` class and
   override the public methods to fit your needs.

   - [[getItemCount]]: the number of items;
   - [[getItemAt]]: the item at some specified index;
   - [[getIndexOf]]: the index of some item.

   Whenever data is added, removed, updated or re-ordered, the model shall be
   informed by calling one of the following methods:

   - [[updateItem]] when an individual item shall be re-rendered (if ever visible)
   - [[updateIndex]] when a range of item indices shall be re-rendered (if ever visible)
   - [[reload]] for all other modifications of the collection, including addition, removal, filtering and re-ordering.

   Item count and indices shall be consistent with the currently applied filters and ordering, if any.

   @template A - the type of items.
   Each row in the model shall be uniquely identified by its item value.
   Values to be displayed in each column of table views shall not be part of the item value.
   Items will be used to keep track of selection and scrolling during model updates.

*/
export abstract class Model<A> {

  #clients = new Map<ClientId, Client>();
  #clientId = 0;

  /**
     Shall return the number of items to be displayed by the table.
     Negative values are considered as zero.
  */
  abstract getItemCount(): number;

  /**
     Shall return the item at a given index in the table with respect to
     current filtering and ordering (if appropriate).
  */
  abstract getItemAt(index: number): undefined | A;

  /**
     Shall return the index of a given item inside the table with respect to
     current filtering and ordering, or `undefined` if no such item exists.
     Any negative returned index would be treated as `undefined`.
  */
  abstract getIndexOf(item: A): undefined | number;

  /**
     Signal an item update.
     All views that might be rendering the specified item will rerender the associated row.
  */
  updateItem(item: A) {
    const k = this.getIndexOf(item);
    if (k !== undefined && 0 <= k) this.updateIndex(k);
  }

  /**
     Signal a range of updates
     @param first - the first updated item index
     @param last - the last updated item index (defaults to `first`)
  */
  updateIndex(first: number, last = first) {
    if (first <= last) {
      this.#clients.forEach(({ lower, upper, trigger }) => {
        if (first <= upper && lower <= last) trigger();
      });
    }
  }

  /** Re-render all items */
  reload() { this.#clients.forEach(({ trigger }) => trigger()); }

  /**
     Connect a client view to the model.
     The initial watching range is empty.
  */
  bind(trigger: () => void): ClientId {
    const id = "#" + this.#clientId++;
    this.#clients.set(id, { lower: 0, upper: 0, trigger });
    return id;
  }

  /**
     Disconnect a client from the model.
  */
  remove(id: ClientId) {
    this.#clients.delete(id);
  }

  /**
     Set the current range of items currently watched by the client.
     Data updates that fall outside this range will _not_ trigger
     re-rendering of the client.
     @param lower - first item index rendered
     @param upper - last item index rendered
  */
  watch(id: ClientId, lower: number, upper: number) {
    const listener = this.#clients.get(id);
    if (listener) {
      listener.lower = lower;
      listener.upper = upper;
    }
  }

}

// --------------------------------------------------------------------------
