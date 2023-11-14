/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Table of (multiple) locations
// --------------------------------------------------------------------------

import React from 'react';
import { GlobalState, useGlobalState } from 'dome/data/states';
import * as States from 'frama-c/states';

import { CompactModel } from 'dome/table/arrays';
import { Table, Column, Renderer } from 'dome/table/views';
import { Label, Cell } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Space } from 'dome/frame/toolbars';
import { TitleBar } from 'ivette';
import * as Ast from 'frama-c/kernel/api/ast';

// --------------------------------------------------------------------------
// --- Global Multi-Selection
// --------------------------------------------------------------------------

export interface MultiSelection {
  label: string;
  title?: string;
  markers: Ast.marker[];
  index?: number;
}

const emptySelection = { label: '', title: '', markers: [], index: 0 };
const MultiSelection = new GlobalState<MultiSelection>(emptySelection);

export function useSelection(): MultiSelection {
  const [s] = useGlobalState(MultiSelection);
  return s;
}

export function setSelection(s: MultiSelection): void
{
  MultiSelection.setValue(s);
  const marker = s.index !== undefined ? s.markers[s.index] : undefined;
  if (marker) States.setSelected(marker);
}

export function setIndex(index: number): void {
  const s = MultiSelection.getValue();
  setSelection({ ...s, index });
}

function sameMarkers(xs: Ast.marker[], ys: Ast.marker[]): boolean
{
  if (xs.length !== ys.length) return false;
  for (let k = 0; k < xs.length; k++)
    if (xs[k] !== ys[k]) return false;
  return true;
}

function sameSelection(u: MultiSelection, v: MultiSelection): boolean
{
  if (u.label !== v.label) return false;
  if (u.title !== v.title) return false;
  return sameMarkers(u.markers, v.markers);
}

/**
   Update the list of markers and select its first element,
   or cycle to the next element wrt current selection.
 */
export function setNextSelection(s: MultiSelection): void
{
  const selection = MultiSelection.getValue();
  if (s.index === undefined && sameSelection(selection, s)) {
    const { index, markers } = selection;
    const target = index === undefined ? 0 : index+1;
    const select = target < markers.length ? target : 0;
    setSelection({ ...selection, index: select });
  } else {
    setSelection(s);
  }
}

export function clearSelection(): void {
  MultiSelection.setValue(emptySelection);
}

function gotoIndex(index: number): void {
  const selection = MultiSelection.getValue();
  if (0 <= index && index <= selection.markers.length)
    setSelection({ ...selection, index });
}

// --------------------------------------------------------------------------
// --- Locations Panel
// --------------------------------------------------------------------------

interface Data {
  index: number,
  marker: Ast.marker,
}

class Model extends CompactModel<Ast.marker, Data> {
  constructor() { super(({ marker }) => marker); }
}

const getIndex = (d : Data): number => d.index + 1;

const renderCell: Renderer<string> =
  (text: string): JSX.Element => (<Cell title={text}>{text}</Cell>);

export default function LocationsTable(): JSX.Element {

  // Hooks
  const model = React.useMemo(() => new Model(), []);
  const getDecl = States.useSyncArrayGetter(Ast.declAttributes);
  const getAttr = States.useSyncArrayGetter(Ast.markerAttributes);
  const { label, title, markers, index } = useSelection();
  React.useEffect(() => {
    model.replaceAllDataWith(
      markers.map((marker, index): Data => ({ index, marker }))
    );
  }, [model, markers]);
  const selected = index !== undefined ? markers[index] : undefined;
  const size = markers.length;
  const kindex = index === undefined ? (-1) : index;
  const indexLabel = index === undefined ? '…' : index+1;
  const positionLabel = `${indexLabel} / ${size}`;

  const getLocation = React.useCallback((d: Data): string => {
    const attr = getAttr(d.marker);
    if (!attr) return '';
    const decl = getDecl(attr.scope);
    if (!decl) return '';
    return `${decl.name}: ${attr.descr}`;
  }, [getDecl, getAttr]);

  // Component
  return (
    <>
      <TitleBar>
        <IconButton
          icon='ANGLE.LEFT'
          title='Previous location'
          enabled={0 < kindex}
          onClick={() => gotoIndex(kindex-1)}
        />
        <IconButton
          icon='ANGLE.RIGHT'
          title='Next location'
          enabled={(-1) <= kindex && kindex + 1 < size}
          onClick={() => gotoIndex(kindex+1)}
        />
        <Space />
        <Label
          className='component-info'
          display={0 < size}
          label={positionLabel}
          title='Current location index / Number of locations' />
        <Space />
        <IconButton
          icon='TRASH'
          title='Cancel selected locations'
          onClick={clearSelection}
        />
      </TitleBar>
      <Label label={label} title={title} style={{ textAlign: 'center' }} />
      <Table<Ast.marker, Data>
        model={model}
        display={size >0}
        selection={selected}
        onSelection={(_marker, _data, index) => gotoIndex(index)}
      >
        <Column
          id='index' label='#' align='center' width={25}
          getter={getIndex}
        />
        <Column
          id='marker' label='Location' fill
          getter={getLocation} render={renderCell}
        />
      </Table>
    </>
  );
}

// --------------------------------------------------------------------------
