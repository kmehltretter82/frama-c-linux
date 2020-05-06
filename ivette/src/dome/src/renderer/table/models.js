// --------------------------------------------------------------------------
// --- Models
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/table/models
*/

import _ from 'lodash' ;
import { SortDirection } from 'react-virtualized' ;

// --------------------------------------------------------------------------
// --- Sorting
// --------------------------------------------------------------------------

/** Ascending Order (SortDirection) */
export const ASC = SortDirection.ASC ;

/** Descending Order (SortDirection) */
export const DESC = SortDirection.DESC ;

// --------------------------------------------------------------------------
// --- Collection Model
// --------------------------------------------------------------------------

/**
   @class
   @summary Data Listener.
   @description

   A Model is responsible for keeping the tables and lists views in sync
   with their associated data sets. The model listens for updates, retrieves
   items from their index, and re-render the views when necessary.

   Several tables may connect to the same table model, but they will share the
   same number and ordering of items. However, each connected table will only
   render its own range of items and will re-renderer only when impacted by
   individual updates.


   A Model instance may not hold the data directly. A table or list component
   uses the model only as a _proxy_ reponsible for fetching the items with respect to
   some current filtering and ordering selection. The model also serves as
   a proxy for triggering table re-rendering when table data is updated.


   To design your data model, you shall extends the base `Model` class and
   override the public methods to fit your needs.

   - `getItemCount() -> number` (the number of items)
   - `getItemAt(number) -> item` (the item at the given index)
   - `getIndexOf(item) -> number` (the index of an item in the current order)
   - `getValue(item,column) -> any` (the value associated to some item in a column)


   To implement sorting, you shall also override the following methods:

   - `getOrdering() -> { sortBy, sortDirection }`
   - `setOrdering({ sortBy, sortDirection }) -> ()`


   Whenever data is added, removed, updated or re-ordered, the `Model` shall be
   informed by calling one of the following methods:

   - `updateItem(item);` when an individual item shall be re-rendered (if ever visible)
   - `updateIndex(index[,index]);` when an item or a range of items shall be re-rendered
   - `reload();` for all other modifications of the collection, including filtering and re-ordering


   Items count and items indices shall be consistent with the current filter(s)
   and order(s) selected by the user. Tables are equipped with
   callbacks on table headers that can be used to trigger re-ordering of your data, but
   you can implement your own controls or use menus to do that.

   Items can be represented by any javascript values (string, integers, objects...).
   Default table cell renderers expect items to be object with one property per column, but you
   can override those default. The default `getValue` implementation simply returns the
   item property corresponding to the column identifier.

   When some data is updated, selection and scrolling of the views will be
   preserved based on item's value. Table and List views will
   keep each rendered item in sync with their index thanks to methods `getItemAt`
   and `getIndexOf` that you provide with the Model.

   Hence, items implementation shall contains enough information to uniquely identify them,
   whatever their current index.

   ##### Model Helpers

   The module [[dome/table/arrays]] provides you with
   usefull helpers to implement Models with filtering and ordering features.

*/
export class Model {

  constructor() {
    this._dome_clients = {} ;
    this._dome_clientId = 0 ;
  }

  /**
     @summary Items count.
     @abstract
     @return {number} number of items
     @description
     Shall return the number of items to be displayed by the table.
     Negative values are considered as zero.
     Default implementation returns zero.
   */
  getItemCount() { return 0; }

  /**
     @summary Item at given index.
     @abstract
     @param {number} index - item's ordering index
     @return {any} the item's value
     @description
     Shall return the item at a given index in the table with respect to
     current filtering and ordering (if appropriate).
     <p>
     Default implementation returns `undefined`.
  */
  getItemAt() { return undefined; }

  /**
     @summary Index of an item.
     @abstract
     @param {any} item - the item
     @return {number} index of the item in the filtered and ordered collection
     @description
     Shall return the index of a given item inside the table with respect to
     current filtering and ordering, or `undefined` if no such item exists.
     <p>
     Default implementation returns `undefined`.
  */
  getIndexOf() { return undefined; }

  /**
     @summary Item value in a column.
     @param {any} item - an item
     @param {string} column - a column identifier
     @return {any} the value associated to the item for the given column.
     @description
     Defaults to accessing the column property of the item (ie. `item[column]`).
     This method can be overriden by custom models and also table columns.
   */
  getValue(item,column) { return item[column]; }

  /**
     @summary Re-render an item.
     @param {any} item - the updated item
     @description
     Signal that a given item has been updated and need to be re-rendered if visible.
  */
  updateItem(item) {
    const k = this.getIndexOf(item);
    if ( 0 <= k ) this.updateIndex(k);
  }

  /**
     @summary Re-render a range of items.
     @param {number} first - the first updated item index
     @param {number} [last] - the last updated item index (defaults to `first`)
     @description
     Signal that a range of items have been updated and need to be re-rendered if visible.
  */
  updateIndex(a,b=a) {
    _.forOwn(this._dome_clients,({ lower,upper,trigger }) => {
      if ( a <= upper && lower <= b ) trigger();
    });
  }

  /** Re-render all items */
  reload() { _.forOwn(this._dome_clients,({trigger})=> trigger()); }

  /**
     @summary Current ordering.
     @return {object} current sorting order
     @description
     Shall return the current ordering `{ sortBy, sortDirection }`
     for user feedback in table headers, and `undefined` for natural ordering
     or no ordering at all.
     <p>
     Default implementation returns `undefined`.
  */
  getOrdering() { return undefined; }

  /**
     @summary Change ordering of the model.
     @param {object} [sort] - sorting order
     @description
     Callback to user clicks on table headers. This method receives
     the new `{ sortBy, sortDirection }` ordering requested by the user action,
     of `undefined` to reset initial, natural ordering of items.
     You can also invoke this method on your own, away from any table view.
     <p>
     The method shall eventually reorder the items internally, and finally
     signal completion with a call to `Model.reload()` in order to sync the views.
     If re-ordering can take a while, this shall be performed asynchronously.
     <p>
     Default implementation does nothing.
  */
  setOrdering() { }

  /**
     @summary Connect a trigger to the model.
     @protected
     @param {Function} trigger - callback to force table update
     @return {ClientID} client identifier
     @description
     Returns a _client_ identifier for removing and watching.
     The trigger function is called for each update watched by the _client_.
     Initially, the watching range is empty.
  */
  _bind(trigger) {
    const client = "#" + this._dome_clientId++ ;
    this._dome_clients[client] = { lower:0, upper:0, trigger };
    return client;
  }

  /**
     @summary Disconnect the _client_ from the model.
     @protected
     @param {ClientID} client - the identifier of the client to disconnect
  */
  _remove(client) {
    delete this._dome_clients[client];
  }

  /**
     @summary Set the current range of items watched by the _client_.
     @protected
     @param {ClientID} client - the identifier of the client to disconnect
     @param {number} first - first index of the range
     @param {number} last - last index of the range
     @description
     Data updates tha fall outside this range will _not_ trigger
     re-rendering of the client.
  */
  _watch(client,a,b) {
    const listener = this._dome_clients[client];
    if (listener) { listener.lower = a ; listener.upper = b; }
  }

}

// --------------------------------------------------------------------------
