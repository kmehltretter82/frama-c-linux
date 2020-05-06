// --------------------------------------------------------------------------
// --- Table Models
// --------------------------------------------------------------------------

/** @module dome/table/arrays */

import _ from 'lodash' ;
import React from 'react' ;
import { Model, ASC, DESC } from 'dome/table/models' ;

// --------------------------------------------------------------------------
// --- Ordering
// --------------------------------------------------------------------------

// Compute the value of an item
const getValueWith =
      ( item , value ) =>
      ( item === undefined ? undefined :
        typeof(value) === 'function' ? value(item) :
        item[value] );

// Compute the primary ordering function
const comparisonWith = (sorting) => {
  switch(typeof(sorting)) {

  case 'function':
    return sorting ;

  case 'string':
    return (a,b) => {
      if ( a === b ) return 0 ;
      if ( a === undefined ) return 1 ;
      if ( b === undefined ) return -1 ;
      const va = a[sorting];
      const vb = b[sorting];
      if ( va === vb ) return 0;
      if ( va === undefined ) return 1 ;
      if ( vb === undefined ) return -1 ;
      if ( va < vb ) return -1;
      if ( va > vb ) return 1;
      return 0;
    };

  case 'object':
    const { sortBy, sortDirection=ASC } = sorting ;
    return (a,b) => {
      if ( a === b ) return 0 ;
      if ( a === undefined ) return 1 ;
      if ( b === undefined ) return -1 ;
      const isFun = typeof(sortBy)==='function' ;
      const va = isFun ? sortBy(a) : a[sortBy] ;
      const vb = isFun ? sortBy(b) : b[sortBy] ;
      if ( va === vb ) return 0;
      if ( va === undefined ) return 1 ;
      if ( vb === undefined ) return -1 ;
      switch(sortDirection) {
      case ASC:
        if (va < vb) return -1;
        if (va > vb) return 1;
        break;
      case DESC:
        if (va < vb) return 1;
        if (va > vb) return -1;
        break;
      }
      return 0;
    };

  default:
    return () => 0;

  }
};

// Make a chainable order
const chainableOrder = ( order ) => {

  const compare = (a,b) => {
    for (var k = 0; k < order.length ; k++) {
      const cmp = (order[k])(a,b);
      if (cmp !==0 ) return cmp;
    }
    return 0;
  };

  compare.thenWith = (sorting) =>
    sorting ?
    chainableOrder( order.slice().push(comparisonWith(sorting)) )
    : compare ;

  return compare ;
};

/**
   @summary Comparison helper.
   @method
   @param {any} sorting - the sorting properties
   @return {function} the corresponding comparison function
   @description

This function is a helper for comparing items, by comparing
values extracted from them with chaining. It returns
a comparison function that you can use, for instance,
in `Array.sort` fort sorting arrays.

##### Comparison

The comparison order is defined according the `sorting` parameter
provided to the helper:

If `sorting` is a function, it is used as the primary comparison function.
When items compare equal, chained comparisons are used to refine the
ordering (see Chaining below).

If `sorting` is a property name (a string), items `a` and `b` are ordered
by comparing their respective values `a[sorting]` and `b[sorting]` for
this property.

If `sorting` as an object, it shall provides `{ sortBy, sortDirection }`
properties and the comparison function is defined as follows:
- `sortBy` can be a function or a property name.
If a function is given, items `a` and `b` are ordered by comparing
values `sortBy(a)` and `sortBy(b)`. Otherwize, they are ordered by
comparing `a[sortBy]` and `b[sortBy]`.
- `sortDirection` can be either `ASC` for normal comparison or `DESC`
for reversing the comparison.
If no direction is given (or any other value) `ASC` is assumed.

When computing comparison, `undefined` values are _always_ rejected to the
end of the ordering, whatever the specified direction.

##### Chaining

The returned comparison function can be chained with a secondary
comparison function, which will be used when two items compare equal.

You can chain as many comparison functions you want by using
`.thenWith(sorting)` like in the example below. Each call to `.thenWith` returns
a different comparison function that can be safely forked with subsequent calls
to `.thenWith` as illustrated in the second example.

Remark than `compareWith` and `.thenWith` also accept undefined or null values, which
are considered neutral.

@example
// Chaining Comparison
items.sort(
  compareWith({sortBy:'name',sortDirection: ASC})
    .thenWith( (a,b) => a.priority - b.priority )
    .thenWith({sortBy:'age',sortDirection: DESC})
);

@example
// Forking Comparison
const primary = compareWith( (a,b) => a.priority - b.prioroty );
const byName = primary.thenWith('name');
const byAge = primary.thenWith('age');

*/
export const compareWith =
  ( sorting ) =>
  ( sorting ? chainableOrder([ comparisonWith(sorting) ]) : () => 0 );

// --------------------------------------------------------------------------
// --- Comparison Ring
// --------------------------------------------------------------------------

/**
   @class
   @summary Helper for column comparison.
   @description
A comparison ring can be used to implement column ordering, where each
column selection _refines_ the previous ordering.

Hence, the ring holds the current comparison order and it is well suited
for being used in conjunction with [Table](module-dome_table_views.Table.html)
components.

A comparison specification can be a property name or a function.
See [compareWith](module-dome_table_arrays.html#compareWith) for more details.
By default, the ring uses the column identifier as a property name for comparing.

Initially, the ordering is _natural_.
*/
export class ComparisonRing {

  /**
     @param {id|function} [natural] - default (natural) order
  */

  constructor(natural) {
    this.columns = {} ;
    this.natural = natural && comparisonWith(natural) ;
    this.compare = this.compare.bind(this);
    this.ring = [] ;
    this.sort = undefined ;
  }

  /**
     @summary Current order comparison.
     @description
     Returns the comparison function corresponding to the current order.
     The comparison function is _chainable_, see
     [compareWith](module-dome_table_arrays.html#compareWith) for more details.
  */
  compareWith()
  {
    if (!this.sort) {
      const ordering = this.ring.map(
        ({sortBy,sortDirection}) =>
          comparisonWith({
            sortBy: this.columns[sortBy] || sortBy ,
            sortDirection
          })
      );
      if (this.natural) ordering.push(this.natural);
      this.sort = chainableOrder(ordering);
    }
    return this.sort;
  }

  /**
     @summary Refine current order comparison.
     @description
     Short cut for `this.compareWith().thenWith(sorting)`
  */
  thenWith(sorting) {
    return this.compareWith().thenWith(sorting);
  }

  /**
     @summary Get value for ordering a column.
     @param {any} item - the item to compare with
     @param {string} column - the column identifier
     @return {any} item's value for the column
     Returns the value used to order an item within a given column.
  */
  getValue(item,column) {
    return getValueWith(item,this.columns[column] || column);
  }

  /**
     @summary Set value to order a column.
     @param {string} column - column identifier
     @param {string|function} [value] - value accessor (defaults to `column`)
     @description
     Set the sorting specification (property name or function) for the given column.
  */
  setValue( column , value ) {
    this.columns[column] = value ;
  }

  /** Sets natural ordering (property name or value accessor) */
  setNatural( natural ) {
    this.natural = natural ;
  }

  /** @summary Compare two items with respect to the current ordering.
      @description
      You can use `this.compare` as a closure to the current comparison function
      (no need for `this.compare.bind(this)`).
   */
  compare(a,b) {
    return this.order()(a,b);
  }

  /** @summary Return current ordering.
      @return {object} ordering specification
      @description
      Return the last `{ sortBy, sortDirection }` ordering.
      Shall be used for the Table view. */
  getOrdering() {
    return this.ring[0] ;
  }

  /**
     @summary Specify current ordering.
     @param {object} sorting - the new ordering
     @description
     Use the specified `{ sortBy, sortDirection }` ordering, and refine it with
     the previous one.

     If `sorting` is undefined, reset the ring to the natural ordering.
  */
  setOrdering( sorting ) {
    if (sorting) {
      const key = sorting.sortBy ;
      this.ring = this.ring.filter( (s) => s.sortBy !== key );
      this.ring.unshift( sorting );
    } else {
      this.ring = [] ;
    }
    this.sort = undefined ;
  }

}

// --------------------------------------------------------------------------
// --- Unsorted Model
// --------------------------------------------------------------------------

/**
   @summary A table Model for unsorted datasets.
   @description

   This class implements a simple [Model](module-dome_table_models.Model.html)
   where item's are identified by their index. Such a model is not adapted to
   re-ordering and filtering, because table views will have no way to synchronize
   the selected index before and after re-ordering, hence the name.

*/

export class UnsortedModel extends Model {

  /**
      @param {number} [count] - the initial size (default `0`)
   */
  constructor(count=0) {
    super();
    this.count = count < 0 ? 0 : count ;
  }

  /**
     @summary Set the number of items.
     @param {number} n - the number of items
     @param {boolean} [reload] - force reloading (false by default)
     @description
     Triggers a reload if the item count has changed,
     unless you force it.
  */
  setItemCount(n,reload=false) {
    if (n<0) n=0;
    if ( reload || n != this.count ) {
      this.count = n ;
      this.reload();
    }
  }

  getItemCount() { return this.count; }

  /** Identity, or `undefined` when out of range. */
  getItemAt(k) {
    return 0 <= k && k < this.count ? k : undefined ;
  }

  /** Identity, or `-1` when out of range. */
  getIndexOf(k) {
    return 0 <= k && k < this.count ? k : -1 ;
  }

}

// --------------------------------------------------------------------------
// --- Array Model
// --------------------------------------------------------------------------

/**
   @summary A table Model based on array.
   @extends Model
   @description

   This class implements a simple [Model](module-dome_table_models.Model.html)
   implementation where item's are stored in an array. The model supports built-in
   ordering thanks with a
   [ComparisonRing](module-dome_table_arrays.ComparisonRing.html)
   with additional filtering capabilities.

   The model keep items in sync with their ordered & filtered index by
   injecting an `index` property in them each time the collection is re-ordered.
   You shall not use `index` property for your own needs.

   Item objects can be modified in place, but you shall call `model.updateItem(item)`
   or `model.reload()` to re-renderer the associated (visible) cells.
 */
export class ArrayModel extends Model {

  /** Initially empty model */
  constructor() {
    super();
    this.ring = new ComparisonRing('index'); // Used for stable sorting
    this.data = []; // Array of item elements
  }

  /** Remove all items (and reload) */
  clear() {
    this.data = [] ;
    this.reload();
  }

  /** Add one or more items (and reload) */
  add( ...items ) {
    this.data.push(...items);
    this.reload();
  }

  /**
     @summary Model items array.
     @description
Returns the internal item array holding _all_ the items in the model.

This array is _not_ sortered and filtered. You can obtain the current index of an item in
table views by accessing its `item.index` property, which is `undefined` if the item has been
filtered out.

If you modify the internal item array, don't forget to call `reload()` after modifications
in order to keep views in sync.
   */
  getData() { return this.data; }

  /** Replace the entire collection of items */
  setData(data) {
    this.data = data || [] ;
    this.reload();
  }

  _order() {
    if (!this.order) {
      const filter = this.filtering ;
      const compare = this.ring.compareWith();
      const ordered = this.data.filter((item,index) => {
        const ok = filter ? filter(item) : true ;
        // Index inside initial collection is used for stable sort
        item.index = ok ? index : undefined ;
        return ok ;
      }).sort(compare);
      // Now set index in filtered & sorted collection
      ordered.forEach((item,index) => item.index = index);
      this.order = ordered ;
    }
    return this.order ;
  }

  /** Return a _copy_ of the visible items. */
  getItems() { return this._order().slice(); }

  // MODEL Interface
  getItemCount() { return this._order().length; }

  // MODEL Interface
  getItemAt(index) { return this._order()[index] ; }

  // MODEL Interface
  getIndexOf(item) { return item && item.index ; }

  /** @summary Current filtering function.
      @return {function} `undefined` means no filtering
  */
  getFiltering() { return this.filtering ; }

  /** @summary Set the filtering function.
      @param {function} [filter] - The filter function
      @description
      The filtering function is used to filter out items to be displayed.
      It is invoked as `filter(item)` and shall return a truthly value when `item`
      must be displayed.
  */
  setFiltering(filter) {
    this.filtering = filter ;
    this.reload();
  }

  // MODEL Interface
  getOrdering() { return this.ring.getOrdering(); }

  // MODEL Interface
  setOrdering(order) {
    if (order === undefined || order.sortBy !== 'index')
    {
      this.ring.setOrdering(order);
      this.reload();
    }
  }

  // MODEL Interface
  getValue( item , column ) {
    return this.ring.getValue( item , column );
  }

  /** Set the value-getter for the given column */
  setValue( column , value ) {
    this.ring.setValue(column,value);
    this.reload();
  }

  // MODEL Interface
  reload() {
    this.order = undefined ;
    super.reload();
  }
}

// --------------------------------------------------------------------------
// --- Model Hook
// --------------------------------------------------------------------------

/**
   @summary Uses a new array model (Custom React Hook).
   @param {Collection} [items] - the array items
   @description
   This hook is a convenient way to have a local array model with full featured
   sorting and filtering fonctionnalities, which is automatically updated
   with the provided items.

   The array model is created once and updated at each render.
   Items can be specified with a lodash collection.

   @example // Array Model
   const MyView = () => {
      Dome.useUpdate( MyUpdateEvent );
      const model = useArrayModel(getMyItems());
      return (<Table model={model} … >…</Table>) ;
   };

*/
export function useArrayModel( items )
{
  const model = React.useMemo( () => new ArrayModel() , [] );
  model.setData( _.toArray(items) );
  return model;
}

// --------------------------------------------------------------------------
