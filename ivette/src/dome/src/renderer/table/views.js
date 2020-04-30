// --------------------------------------------------------------------------
// --- Tables
// --------------------------------------------------------------------------

/** @module dome/table/views */

import _ from 'lodash' ;
import React from 'react' ;
import * as Dome from 'dome' ;
import { DraggableCore } from 'react-draggable';
import { SVG } from 'dome/controls/icons' ;
import {
  AutoSizer,
  SortDirection,
  Table as VTable,
  Column as VColumn
} from 'react-virtualized' ;

import './style.css' ;

// --------------------------------------------------------------------------
// --- Header Renderer
// --------------------------------------------------------------------------

const headerRowRenderer =
      (contextMenu) =>
      // Borrowed from react-virtualized Table.defaultHeaderRowRenderer
      ({
        className,
        columns,
        style
      }) => (
        <div role="row"
             className={className}
             style={style}
             onContextMenu={contextMenu} >
          {columns}
        </div>
      );

const headerIcon = (icon) => (
  icon && <div className='dome-xTable-header-icon'><SVG id={icon}/></div>
);

const headerLabel = (label) => (
  label &&
    (<label className='dome-xTable-header-label dome-text-label'>
     {label}
     </label>)
);

const makeSorter = (id) => (
  <div className='dome-xTable-header-sorter'>
    <SVG id={id} size={8}/>
  </div>
);

const headerSorter = {} ;
headerSorter[ SortDirection.ASC ] = makeSorter('ANGLE.UP');
headerSorter[ SortDirection.DESC ] = makeSorter('ANGLE.DOWN');

const headerRenderer =
      ({
        columnData: { label, icon, title, headerRef },
        dataKey,
        sortBy,
        sortDirection
      }) => {
        const tooltip = title || label ;
        const onRef = (elt) => headerRef(dataKey,elt) ;
        const sorter = dataKey === sortBy ? headerSorter[sortDirection] : undefined ;
        return (
          <div className='dome-xTable-header' title={tooltip} ref={onRef} >
            { headerIcon(icon) }
            { headerLabel(label) }
            { sorter }
          </div>
        );
      };

// --------------------------------------------------------------------------
// --- Cell Renderer
// --------------------------------------------------------------------------

const cellDataGetter =
      (getValue) =>
      ({ rowData:{ model , item }, dataKey:id }) =>
      ( item == undefined ? undefined :
        getValue ? getValue(item) :
        model.getValue(item,id)
      );

const cellRenderer =
      (renderValue) =>
      ({ cellData: data }) =>
      (
        data === undefined ? undefined :
        renderValue ? renderValue(data) :
        (<div className='dome-xTable-cell dome-text-data'>{data}</div>)
      );

// --------------------------------------------------------------------------
// --- Column Resizer
// --------------------------------------------------------------------------

const DRAGGING = 'dome-xTable-resizer dome-color-dragging' ;
const DRAGZONE = 'dome-xTable-resizer dome-color-dragzone' ;

const Resizer = (props) => (
  <DraggableCore
    onStart={props.onStart}
    onStop={props.onStop}
    onDrag={(_elt,data)=> props.onDrag(props.left,props.right,data.x - props.offset)}
    >
    <div
      className={ props.id === props.dragging ? DRAGGING : DRAGZONE }
      style={{ left: props.offset-2 }}
      />
  </DraggableCore>
);

const computeWidth = (elt) => {
  const parent = elt && elt.parentElement ;
  return parent && parent.getBoundingClientRect().width ;
};

// --------------------------------------------------------------------------
// --- Table Columns
// --------------------------------------------------------------------------

/**
   @summary Table Column.
   @property {string} id - Column unique identifier (required)
   @property {string} [icon] - Header icon
   @property {string} [label] - Header label
   @property {string} [title] - Header tooltip
   @property {string} [align] - Column alignment (`'left'`, `'center'`, `'right'`)
   @property {number} [width] - Column base width (in pixels, default `60`)
   @property {boolean} [fill] - Extensible column (not by default)
   @property {boolean} [fixed] - Non-resizable column (not by default)
   @property {boolean} [disableSort] - Do not trigger sorting callback for this column
   @property {boolean|string} [visible] - Default column visibility
   @property {function} [getValue] - Obtain an item's value for this column
   @property {function} [renderValue] - Render item's value in each table cell
   @description

   Each column displays a specific value derived from the item displayed in a
   row. Column properties enforce a separation between how to extract the value
   from an item and how to render it in the cell.

   - `getValue(item) : any` shall returns the value to render for the _item_
   - `renderValue(any) : Element` shall returns the (React) element to display the item


   By default, values are obtained from the underlying model by invoking
   [Model.getValue](module-dome_table_models.Model.html#getValue) with the column
   identifier.

   The default `renderValue` renders the item's value
   packed in a `<label>` with class `dome-text-data` as described in the
   [Styling Component](tutorial-styling.html) tutorial.

   This separation of concerns allows for defining
   Column types, where for instance the renderer is already defined and you only need to
   know how to extract the expected value of items.
   See [DefineColumn](module-dome_table_views.DefineColumn.html)
   for more informations and examples.

   A table should have at least one extensible column to occupy the available width.
   If no column in the table is explicitely declared to be extensible, the last
   one would be implicitely set to fill.

   Default visiblity can be set to a boolean value ; alternatively, you may specify
   `visible='never'` to make the column invisible to the user, or `visible='always'`
   to force the column to be visible.

*/
export const Column = (props) => null;
// Fake component only used to store props.
// Virtualized column is rendered with function vColumn (see below)

const vColumn = ({
  headerRef,
  columnResize,hasFill,lastElt,
  contextMenu
}) => (elt) => {
  const defaults = elt.type._DOME_COLUMN_DEFAULTS || {} ;
  const forcers = !hasFill && elt == lastElt ? { fill:true } : {} ;
  const { id,label,title,icon,align,width,fill,disableSort,getValue,renderValue }
        = Object.assign( {}, defaults , elt.props , forcers ) ;
  return (
    <VColumn
      key={id}
      displayName='React-Virtualized-Column'
      width={columnResize[id] || width || 60}
      flexGrow={ fill ? 1 : 0 }
      dataKey={id}
      columnData={{label,title,icon,headerRef}}
      headerRenderer={headerRenderer}
      cellRenderer={cellRenderer(renderValue)}
      cellDataGetter={cellDataGetter(getValue)}
      headerStyle={{ textAlign: align }}
      disableSort={disableSort}
      style={{ textAlign: align }}
      />
  );
};

const defaultVisible = (visible) => {
  switch(visible) {
  case 'always':
  case undefined:
    return true;
  case 'never':
  case null:
    return false;
  default:
    return visible;
  }
};

// --------------------------------------------------------------------------
// --- Specific Columns
// --------------------------------------------------------------------------

/**
   @summary Define specific Column instances.
   @param {Object} properties - default Column properties
   @return {Column} a new Column class of Component
   @description

   Allow to define specialized instances of
   [Column](module-dome_table_views.Column.html)

   @example // Example of column type
   import { DefineColumn } from 'dome/table/views' ;
   export const ColumnCheck = DefineColumn({
     align: 'center',
     renderValue: (ok) => <Icon id={ok ? 'CHECK' : 'CROSS'}/>
   });

   @example // Usage in a Table
   <Table ...>
      <Column id='name' label='Name' fill />
      <ColumnCheck id='check' label='Checked' />
   </Table>

 */
export const DefineColumn = (DEFAULTS) => {
  function Component() { return null; };
  Component._DOME_COLUMN_DEFAULTS = DEFAULTS ;
  return Component ;
};

// --------------------------------------------------------------------------
// --- Table Rows
// --------------------------------------------------------------------------

const rowClassName =
      (multipleSelection,selected) =>
      ({index}) =>
      (multipleSelection
       ? 0 <= _.sortedIndexOf( selected , index )
       : (index === selected))
      ? 'dome-color-selected' :
      index & 1 ? 'dome-xTable-even' : 'dome-xTable-odd' ;

// --------------------------------------------------------------------------
// --- Table View
// --------------------------------------------------------------------------

// Must be kept in sync with table.css
const CSS_HEADER_HEIGHT = 22 ;
const CSS_ROW_HEIGHT = 20 ;
const DEFAULT_STATE = { width:{}, resize:{}, visible:{} };

/**
   @class
   @summary Table View.
   @property {Model} model - table data proxy (required)
   @property {Column[]} children - one or more table columns (required)
   @property {string} [settings] - window settings for column size & visibility (optional)
   @property {any} [selection] - current selection (depends on `multipleSelection`)
   @property {function} [onSelection] - callback to selection changes (depends on `multipleSelection`)
   @property {boolean} [multipleSelection] - select single or multiple selection
   @property {any} [scrollToItem] - ensures the item is visible
   @property {function} [renderEmpty] - callback to render an empty table
   @description

   This component is base on [React-Virtualized
   Tables](https://bvaughn.github.io/react-virtualized/#/components/Table),
   offering a lazy, super-optimized rendering process that scales on huge
   datasets.

   A table shall be connected to an instance of
   [Model](module-dome_table_models.Model.html) class to retrieve the data and
   get informed of data updates.

   The table columns shall be instances of
   [Column](module-dome_table_views.Column.html) class.

   Clicking on table headers trigger re-ordering callback on the model with the
   expected column and direction, unless disabled _via_ the column
   specification. However, actual sorting (and corresponding feedback on table
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
export class Table extends React.Component {

  constructor(props)
  {
    super(props);

    // Table Reload
    this.tableRef = undefined ;
    this.setTableRef = (ref) => this.tableRef = ref ;
    this.reloadTable = () => {
      this.reloaded = true ;
      setImmediate(() => {
        const ref = this.tableRef ;
        if (ref) {
          this.forceUpdate();
          ref.forceUpdateGrid();
        }
      });
    };

    // Model Watching
    this.watchModel = ({startIndex,stopIndex}) => {
      this.props.model._watch( this.client , startIndex , stopIndex );
    };

    // Default Context Menu
    this.resetOrdering = () => this.props.model.setOrdering() ;

    // Column States
    this.state = Object.assign(
      DEFAULT_STATE,
      Dome.getWindowSetting( this.props.settings )
    );
    this.restoreDefaults = () => this.setState( DEFAULT_STATE );

    // Header Reset Resizing
    this.resetResizing = () => this.setState({ width:{}, resize:{} });

    // Header Column References
    this.headerRef = (id,elt) => {
      const old = this.state.width[id] ;
      const current = computeWidth(elt);
      if (elt && old !== current) {
        const columns = Object.assign( {}, this.state.width );
        columns[id] = current ;
        this.setState({ width: columns });
      }
    };

    // Column Resizing
    this.resizeColumns = (lcol,rcol,delta) => {
      const columnSize = this.state.width ;
      const wl = columnSize[lcol] + delta ;
      const wr = columnSize[rcol] - delta ;
      if (wl > 40 && wr > 40) {
        const resize = Object.assign( {}, this.state.resize );
        resize[lcol] = wl ;
        resize[rcol] = wr ;
        this.setState({ resize });
      }
    };

    // Column Visibility
    this.isVisible = (visible) => (elt) => {
      const props = elt.props ;
      const v = visible[props.id] ;
      if (v !== undefined) return v;
      const p = props.visible ;
      switch( p ) {
      case 'never':
      case null:
        return false;
      case 'always':
      case undefined:
        return true;
      default:
        return p;
      }
    };

    // Selection
    this.selectRow = this.selectRow.bind(this);
    this.contextMenu = this.contextMenu.bind(this);

  }

  // --- Life Cycle (binding to model)

  componentDidMount()
  {
    Dome.on('dome.defaults',this.restoreDefaults );
    this.client = this.props.model._bind(this.reloadTable);
  }

  componentWillUnmont()
  {
    Dome.off('dome.defaults',this.restoreDefaults );
    this.props.model._remove(this.client);
    this.tableRef = undefined ;
  }

  componentDidUpdate()
  {
    Dome.setWindowSetting( this.props.settings, this.state );
  }

  // --- Column Resizers

  computeResizers(columns) {
    // Insert a resizer on each side of non-fixed columns,
    // provided there also exists some non-fixed column on both side.
    if (columns.length < 2) return null;
    const resizing = columns.map( ({props:{id,fixed}}) => ({id,fixed}) );
    var k, cid ;
    for (cid = undefined, k = 0; k < columns.length; k++) {
      const r = resizing[k];
      r.left = cid ;
      if (!r.fixed) cid = r.id ;
    }
    for (cid = undefined, k = columns.length-1; 0 <= k ; k--) {
      const r = resizing[k];
      r.right = cid ;
      if (!r.fixed) cid = r.id ;
    }
    var offset = 0 , resizers = [] ;
    const columnSize = this.state.width ;
    for (k = 0; k < columns.length - 1 ; k++) {
      const width = columnSize[resizing[k].id] ;
      if (!width) return null;
      offset += width ;
      const a = resizing[k];
      const b = resizing[k+1];
      if ((!a.fixed || !b.fixed) && a.right && b.left) {
        const id = k ;
        const onStart = () => { this.dragging = id ; this.forceUpdate(); };
        const onStop = () => { this.dragging = undefined ; this.forceUpdate(); };
        const resizer = (
          <Resizer key={id}
                   id={id}
                   dragging={this.dragging}
                   onStart={onStart}
                   onStop={onStop}
                   onDrag={this.resizeColumns}
                   offset={offset}
                   left={b.left}
                   right={a.right} />
        );
        resizers.push(resizer);
      }
    }
    return resizers ;
  }

  // --- Context Menu

  contextMenu() {
    var has_order ;
    var has_width ;
    var has_default ;
    const children = this.props.children ;
    React.Children.forEach(children, (elt) => {
      if (elt) {
        const { fixed, disableSort, visible } = elt.props ;
        if (!disableSort) has_order = true ;
        if (!fixed) has_width = true ;
        if (visible!=='always' && visible!=='never')
          has_default = true ;
      }
    });
    const items = [
      { label: 'Reset Ordering',
        display:has_order, onClick:this.resetOrdering },
      { label: 'Reset Column widths',
        display:has_width, onClick:this.resetResizing },
      { label: 'Restore Columns defaults',
        display:has_default, onClick:this.restoreDefaults },
      'separator'
    ];
    const visible = Object.assign( {}, this.state.visible );
    React.Children.forEach(children, (elt) => {
      if (elt) {
        switch(elt.props.visible) {
        case 'never':
        case 'always':
          break;
        default:
          const { id, label, title } = elt.props ;
          const checked = this.isVisible(visible)(elt);
          const onClick = () => {
            visible[id] = !checked ;
            this.setState({ visible });
          };
          items.push({ label: label || title, checked, onClick });
        }
      }
    });
    Dome.popupMenu(items);
  }

  // --- Row Selection

  selectRow({event, index, rowData:{item}}) {
    this.focus = item ;
    if (item) {
      const { model, multipleSelection , selection, onSelection } = this.props ;
      if (multipleSelection) {
        const selectedItems =
              selection === undefined ? [] :
              Array.isArray(selection) ? selection :
              [selection] ;
        if (event.metaKey || event.ctrlKey) {
          var s, a ;
          const isClicked = (e) => model.getIndexOf(e) === index ;
          if (_.find( selectedItems , isClicked )) {
            s = _.filter( selectedItems, (e) => model.getIndexOf(e) !== index );
          } else {
            s = selectedItems.slice();
            s.push(item);
            a = index ;
          }
          this.anchor = a ;
          this.anchored = undefined ;
          onSelection(s);
        }
        else if (event.shiftKey && this.anchor) {
          var old = this.anchored || (this.anchored = selection) ;
          var updated = old.slice();
          var anchor = this.anchor ;
          var k ;
          if (anchor < index)
            for (k = anchor ; k <= index ; k++) {
              updated.push(model.getItemAt(k));
            }
          else
            for (k = anchor ; index <= k ; k--) {
              updated.push(model.getItemAt(k));
            }
          // No anchor modification
          onSelection(_.uniqBy(updated, model.getIndexOf.bind(model)));
        }
        else {
          this.anchor = index ;
          this.anchored = undefined ;
          onSelection([item]);
        }
      } else {
        onSelection(item);
      }
    }
  }

  // --- Rendering

  render() {

    const {
      model, renderEmpty,
      multipleSelection, selection, onSelection,
      scrollToItem
    } = this.props ;

    const itemCount = model.getItemCount();
    const ordering = model.getOrdering();
    var selected = undefined ;
    if (selection)
      if (multipleSelection && Array.isArray(selection)) {
        selected = selection.map((elt) => {
          var k = model.getIndexOf(elt);
          return Number.isInteger(k) ? k : -1 ;
        }).sort((a,b) => a-b);
      } else
        selected = model.getIndexOf(selection);

    const rowGetter = ({index}) => ({
      model , item: (index < itemCount ? model.getItemAt(index) : undefined)
    }) ;

    const isVisible = this.isVisible(this.state.visible);
    const columns = React.Children.toArray(this.props.children).filter(isVisible);
    var hasFill = false ;
    var lastElt = undefined ;
    React.Children.forEach(columns,(elt) => {
      if (elt.props.fill) hasFill = true ; else lastElt = elt ;
    });
    const SizedTable = ({ height, width }) => {
      const tableHeight = CSS_HEADER_HEIGHT + CSS_ROW_HEIGHT * itemCount ;
      const smallHeight = itemCount > 0 && tableHeight < height ;
      const rowCount = ( smallHeight ? itemCount + 1 : itemCount) ;
      const reloaded = this.reloaded ;
      if (reloaded) this.reloaded = false ;
      const scrollToIndex =
            scrollToItem ? model.getIndexOf(scrollToItem) :
            reloaded && this.focus ? model.getIndexOf(this.focus) : undefined ;
      const resizers = this.computeResizers(columns);
      const renderColumn = vColumn({
        headerRef: this.headerRef,
        hasFill, lastElt,
        columnResize:this.state.resize
      });
      return (
        <React.Fragment>
          <VTable
            ref={this.setTableRef}
            key='table'
            displayName='React-Virtualized-Table'
            width={width}
            height={height}
            rowCount={rowCount}
            noRowsRenderer={renderEmpty}
            rowGetter={rowGetter}
            rowClassName={rowClassName(multipleSelection,selected)}
            rowHeight={CSS_ROW_HEIGHT}
            headerHeight={CSS_HEADER_HEIGHT}
            headerRowRenderer={headerRowRenderer(this.contextMenu)}
            onRowsRendered={this.watchModel}
            onRowClick={onSelection && this.selectRow}
            sortBy={ordering && ordering.sortBy}
            sortDirection={ordering && ordering.sortDirection}
            sort={model.setOrdering.bind(model)}
            scrollToIndex={ scrollToIndex }
            scrollToAlignment='center'
            >
            {React.Children.map(columns,renderColumn)}
          </VTable>
          {resizers}
        </React.Fragment>
      );
    };
    return (
      <div className='dome-xTable'>
        <AutoSizer key='table'>{SizedTable}</AutoSizer>
      </div>
    );
  }
}

// --------------------------------------------------------------------------
