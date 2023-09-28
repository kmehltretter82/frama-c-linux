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
import { Table, Column } from 'dome/table/views';
import { Label } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Space } from 'dome/frame/toolbars';
import { TitleBar } from 'ivette';
import * as Ast from 'frama-c/kernel/api/ast';

// --------------------------------------------------------------------------
// --- Global Multi-Selection
// --------------------------------------------------------------------------

export interface MultiSelection {
  label: string;
  title: string;
  markers: Ast.marker[];
  index?: number;
}

export interface MultiSelectionState {
  label: string;
  title: string;
  markers: Ast.marker[];
  index: number;
}

const emptySelection = { label: '', title: '', markers: [], index: 0 };
const MultiSelection = new GlobalState<MultiSelectionState>(emptySelection);

export function useSelection(): MultiSelectionState {
  const [s] = useGlobalState(MultiSelection);
  return s;
}

export function setSelection(s: MultiSelection): void
{
  const { index=0, ...data } = s;
  MultiSelection.setValue({ ...data, index });
  States.setSelected(data.markers[index]);
}

export function setIndex(index: number): void {
  const s = MultiSelection.getValue();
  setSelection({ ...s, index });
}

/**
   Update the list of markers and select its first element,
   or cycle to the next element wrt current selection.
 */
export function setNextSelection(locs: Ast.marker[]): void {
  const selection = MultiSelection.getValue();
  const { markers, index } = selection;
  if (markers === locs) {
    const target = index+1;
    const select = target < locs.length ? target : 0;
    setSelection({ ...selection, index: select });
  } else {
    setSelection({ ...selection, markers: locs, index: 0 });
  }
}

export function clear(): void {
  MultiSelection.setValue(emptySelection);
}

function gotoIndex(index: number): void {
  const selection = MultiSelection.getValue();
  if (0 <= index && index <= selection.markers.length)
    MultiSelection.setValue({ ...selection, index });
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
  const selected = markers[index];
  const size = markers.length;

  const indexLabel = `${index+1} / ${size}`;

  const getLocation = React.useCallback((d: Data): string => {
    const attr = getAttr(d.marker);
    if (!attr) return '';
    const decl = getDecl(attr.scope);
    if (!decl) return '';
    return `${decl.label} ${attr.descr}`;
  }, [getDecl, getAttr]);

  // Component
  return (
    <>
      <TitleBar>
        <IconButton
          icon='ANGLE.LEFT'
          title='Previous location'
          enabled={0 < index}
          onClick={() => gotoIndex(index-1)}
        />
        <IconButton
          icon='ANGLE.RIGHT'
          title='Next location'
          enabled={index + 1 < size}
          onClick={() => gotoIndex(index+1)}
        />
        <Space />
        <Label
          className='component-info'
          display={0 <= index && index < size}
          label={indexLabel}
          title='Current location index / Number of locations' />
        <Space />
        <IconButton
          icon='TRASH'
        />
      </TitleBar>
      <Label label={label} title={title} style={{ textAlign: 'center' }} />
      <Table<Ast.marker, Data>
        model={model}
        selection={selected}
        onSelection={(_marker, _data, index) => gotoIndex(index)}
      >
        <Column
          id='index' label='#' align='center' width={25}
          getter={getIndex}
        />
        <Column
          id='marker' label='Location' fill
          getter={getLocation}
        />
      </Table>
    </>
  );
}

// --------------------------------------------------------------------------
