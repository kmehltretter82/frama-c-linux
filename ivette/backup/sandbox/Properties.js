// --------------------------------------------------------------------------
// --- Frama-C Properties Table
// --------------------------------------------------------------------------

import React from 'react' ;
import Dome from 'dome' ;
import { useState, useEffect } from 'react' ;

import { Button } from 'dome/controls/buttons';
import { Vfill, Vbox, Scroll } from 'dome/layout/boxes' ;
import { Splitter } from 'dome/layout/splitters' ;
import { Column, Table } from 'dome/table/views' ;
import { ArrayModel } from 'dome/table/arrays' ;
import { Form, Section, FieldList, FieldCheckbox, FieldRadio } from 'dome/layout/forms' ;

import Server from './server.js' ;
import Events from './Events.js' ;

export default function Properties (props) {
  const model = props.properties;

  /* --- Columns of the table ----------------------------------------------- */

  const columnFile = <Column id='file'
                             label='File' />;
  const columnFct = <Column id='fct'
                            label='Function' />;
  const columnProp = <Column id='property'
                             label='Property'
                             fill />;
  const columnStatus = <Column id='status'
                               label='Status' />;

  /* The default columns displayed. The property column is always shown. */
  const defaultColumns =
        { path:false,
          fct:true,
          status:true,
        };
  /* The columns displayed. Set by the user through a form. */
  const [columnsValue, _] = useState(defaultColumns);

  /* Builds the array of columns according to [columnsValue]. */
  function makeColumns () {
    const columns = new Array();
    if (columnsValue.path)
      columns.push(columnFile);
    if (columnsValue.fct)
      columns.push(columnFct);
    columns.push(columnProp); // Always shown.
    if (columnsValue.status)
      columns.push(columnStatus);
    return columns;
  }

  /* The columns array used by the table. */
  const [ columns, setColumns ] = useState(makeColumns());

  function onChangeColumns () {
    setColumns(makeColumns());
  }

  /* Form to choose the columns displayed. */
  const columns_list =
    <Form value={columnsValue} onChange={onChangeColumns} >
      <Section label="Columns" unfold='false' >
        <FieldCheckbox label="File" path='path' />
        <FieldCheckbox label="Function" path='fct' />
        <FieldCheckbox label="Status" path='status' />
      </Section>
    </Form>;

  /* --- Filters of logical properties ------------------------------------- */

  /* All properties are shown by default. */
  const default_status =
        { valid:true,
          valid_hyp:true,
          unknown:true,
          invalid:true,
          invalid_hyp:true,
          considered_valid:true,
          untried:true,
          dead:true,
          inconsistent:true
        };
  const [status, setStatus] = useState(default_status);

  /* Function filtering the properties by status. */
  function filter (item) {
    switch (item.status) {
    case 'Valid':
    case 'Valid_but_dead': return status.valid;
    case 'Valid_under_hyp': return status.valid_hyp;
    case 'Invalid':
    case 'Invalid_but_dead': return status.invalid;
    case 'Invalid_under_hyp': return status.invalid_hyp;
    case 'Unknown':
    case 'Unknown_but_dead': return status.unknown;
    case 'Considered_valid': return status.considered_valid;
    case 'Never_tried': return status.untried;
    case 'Dead': return status.dead;
    case 'Inconsistent': return status.inconsistent;
    default: return true;
    }
  }

  function onChangeFilter (value, error) {
    model.setFiltering(filter);
  }

  /* Filters selection. */
  const filter_list =
    <Form value={status} onChange={onChangeFilter} >
      <Section label="Status" unfold='true' >
        <FieldCheckbox label="Valid" path='valid' />
        <FieldCheckbox label="Valid under hyp." path='valid_hyp' />
        <FieldCheckbox label="Unknown" path='unknown' />
        <FieldCheckbox label="Invalid" path='invalid' />
        <FieldCheckbox label="Invalid under hyp." path='invalid_hyp' />
        <FieldCheckbox label="Considered valid" path='considered_valid' />
        <FieldCheckbox label="Untried" path='untried' />
        <FieldCheckbox label="Dead" path='dead' />
        <FieldCheckbox label="Inconsistent" path='inconsistent' />
      </Section>
    </Form>;

  /* Table of logical properties. */
  const table = <Table model={model} children={columns} />;

  return (
    <Splitter dir='LEFT' >
      <Vfill> <Scroll> {filter_list} {columns_list} </Scroll> </Vfill>
      <Vfill> {table} </Vfill>
    </Splitter>
  )
}
