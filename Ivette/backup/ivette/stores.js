// --------------------------------------------------------------------------
// --- Items Registry
// --------------------------------------------------------------------------

/** @module @ivette/stores */

import _ from 'lodash' ;

const ALL = () => true ;
const IDENT = /^[a-zA-Z0-9_-]+$/ ;
const SUFFIX = /-[0-9]+$/ ;
const PADDING = (n) => n<10 ? "0"+n : n ;

/**
   @summary Base class for registries.
 */
export class Registry
{

  /** @param {string} prefix - fresh identifier prefix */
  constructor( prefix ) {
    this.items = {} ;
    this.prefix = prefix ;
  }

  /**
      @summary Valid identifiers (letters, digits, dashes and underscores).
      @return {boolean} `true` if the identifier is valid
   */
  isValid(id) {
    return typeof(id)=='string' && id.match( IDENT );
  }

  /**
     @summary Test for freshness identifier.
     @return {boolean} `true` if the identifier is not yet attributed
  */
  isFresh(id) {
    return !this.items[id] ;
  }

  /**
      @summary Creates an identifier.
      @param {string} [id] - the base identifier to starts with
      @return {string} a fresh identifier
      @description
      Returns a fresh identifier with format `<base>-<n>` where
      the base is extracted from `id` (without its `-<n>` suffix, if any).
      The default base is the registry prefix, if any.
  */
  fresh(id) {
    let base = this.prefix ;
    if (id) {
      let m = SUFFIX.exec(id);
      base = m ? id.substring(0,m.index) : id ;
    }
    base += '-' ;
    let kid = 1 ;
    for( ;; ) {
      var a = base + PADDING(kid++) ;
      if (!this.items[a]) break ;
    }
    return a ;
  }

  /**
      @summary Iterates ovee the registry.
      @param {function} job - called with `job(item,id)` in unspecified order
      @description
      If the iteratee returns `false`, the iteration is interrupted.
  */
  forEach(job) { _.forEach( this.items , (item,id) => job(item,id) );
  }

  /**
      @summary Iterates ovee the registry.
      @param {function} test - called with `test(item,id)` in unspecified order
      @description
      Returns the first item such that `test(item,id)` returns a truthy value.
      Returns `undefined` otherwise.
  */
  find(test) { _.find( this.items , (item,id) => test(item,id) ); }

  /**
     Select items from the registry
     @param {object} [options] - filter and ordering options
     @return {item[]} the selected array of items
     @description
Available options are:
- `filter:(item) => boolean` to select some itmes (default: all)
- `sortBy:function | function[] | field | field[]` to sort items by (default: by identifier)

Sorting is done by loadsh [sortBy](https://lodash.com/docs/4.17.11#sortBy) method.
  */
  elements( options )
  {
    const filter = (options && options.filter) || ALL ;
    const sortBy = (options && options.sortBy) || 'id' ;
    const pool = [];
    _.forEach( this.items, (item) => {
      if (filter(item)) pool.push(item);
    });
    return _.sortBy(pool,sortBy);
  }

  /** Register a new item
      @param {object} - the item to register in
      @param {once} - register only fresh items
      @description
Each object shall define the following properties:
- `id:string` item identifier (default to `fresh()`)
- `label:string` _optional_ item display name
- `title:string` _optional_ item short description
  */
  add( item, once=false ) {
    if (!item.id) item.id = this.fresh();
    if (!this.isValid(item.id)) {
      console.warn( `[Ivette:${this.prefix}] invalid identifier (${item.id})` );
      return ;
    }
    if (once && !this.isFresh(item.id)) {
      console.warn( `[Ivette:${this.prefix}] duplicate identifier (${item.id})` );
      return ;
    }
    this.items[item.id] = item ;
  }

  /** Retrieve an item by id
      @param {string} id - item identifier
      @return {object} the associated item
  */
  get(id) { return id ? this.items[id] : undefined; }

  /** Remove an item by id
      @param {string} id - item identifier
   */
  remove( id ) {
    if (id && this.items[id]) {
      delete this.items[id];
    }
  }

  /** Remove all items */
  clear() {
    this.items = {};
  }

}

export default { Registry };

// --------------------------------------------------------------------------
