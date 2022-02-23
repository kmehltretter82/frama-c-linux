/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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

/* eslint-disable @typescript-eslint/explicit-function-return-type */

// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import * as Dome from 'dome';
import { classes } from 'dome/misc/utils';
import { VariableSizeList } from 'react-window';
import { Hpack, Filler } from 'dome/layout/boxes';
import { Inset } from 'dome/frame/toolbars';
import { Icon } from 'dome/controls/icons';
import { Cell } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { ModelProp, EvalStmt, EvalCond } from 'frama-c/plugins/eva/model';

// Frama-C
import * as States from 'frama-c/states';

// Locals
import { SizedArea, HSIZER, WSIZER } from './sized';
import { Diff } from './diffed';
import { sizeof, EvaValues, EvaPointedVar, Evaluation } from './cells';
import { Probe } from './probes';
import { Row } from './layout';
import { Callsite } from './stacks';
import { Stmt } from './valueinfos';
import './style.css';

// --------------------------------------------------------------------------
// --- Cell Diffs
// --------------------------------------------------------------------------

function computeValueDiffs(v: EvaValues, vstate: EvalStmt | EvalCond) {
  let here = v.vBefore;
  let diff: undefined | Evaluation;
  let diff2: undefined | Evaluation;
  function setValue(e?: Evaluation) { if (e) { here = e; diff = v.vBefore; } }
  switch (vstate) {
    case 'Before': diff = v.vAfter; break;
    case 'After': setValue(v.vAfter); break;
    case 'Then': setValue(v.vThen); break;
    case 'Else': setValue(v.vElse); break;
    case 'Cond': diff = v.vThen; diff2 = v.vElse; break;
  }
  const vdiffs = { text: here.value, diff: diff?.value, diff2: diff2?.value };
  return { value: here, vdiffs };
}

// --------------------------------------------------------------------------
// --- Table Cell
// --------------------------------------------------------------------------

interface TableCellProps extends ModelProp {
  probe: Probe;
  row: Row;
}

const CELLPADDING = 12;

function TableCell(props: TableCellProps) {
  const { probe, row, model } = props;
  const [, setSelection] = States.useSelection();
  const { kind, callstack } = row;
  const minWidth = CELLPADDING + WSIZER.dimension(probe.minCols);
  const maxWidth = CELLPADDING + WSIZER.dimension(probe.maxCols);
  const style = { width: minWidth, maxWidth };
  let contents: React.ReactNode = props.probe.marker;
  let valueText = '';
  let pointedVars: EvaPointedVar[] = [];
  const { transient, marker } = probe;
  const focused = model.getFocused();
  const isFocused = focused === probe;

  switch (kind) {

    // ---- Probe Contents
    case 'probes':
      {
        const { stmt, code, label } = probe;
        const textClass = label ? 'dome-text-label' : 'dome-text-cell';
        contents = (
          <>
            <span className={textClass}>{label ?? code}</span>
            <Stmt stmt={stmt} marker={marker} short />
          </>
        );
      }
      break;

    // ---- Values Contents
    case 'values':
    case 'callstack':
      {
        const domain = model.values.getValues(probe, callstack);
        const { condition } = probe;
        const vstate = condition ? model.getVcond() : model.getVstmt();
        const { value, vdiffs } = computeValueDiffs(domain, vstate);
        valueText = value.value;
        const text = vdiffs.text ?? vdiffs.diff;
        const { cols, rows } = sizeof(text);
        let status = 'none';
        if (value.alarms.length > 0) {
          if (value.alarms.find(([st, _]) => st === 'False')) status = 'False';
          else status = 'Unknown';
        }
        if (value.pointedVars.length > 0)
          pointedVars = value.pointedVars;
        const alarmClass = `eva-cell-alarms eva-alarm-${status}`;
        const title = 'At least one alarm is raised in one callstack';
        contents = (
          <>
            <Icon className={alarmClass} size={10} title={title} id="WARNING" />
            <SizedArea cols={cols} rows={rows}>
              <span className={`eva-state-${vstate}`}>
                <Diff {...vdiffs} />
              </span>
            </SizedArea>
          </>
        );
      }
      break;

  }

  // --- Cell Packing
  const className = classes(
    'eva-cell',
    transient && 'eva-transient',
    isFocused && 'eva-focused',
  );
  const onClick = () => {
    const location = { fct: probe.fct, marker: probe.marker };
    setSelection({ location });
    model.setSelectedRow(row);
  };
  const onDoubleClick = () => {
    probe.setPersistent();
    if (probe.zoomable) probe.setZoomed(!probe.zoomed);
  };

  async function onContextMenu() {
    const items: Dome.PopupMenuItem[] = [];
    const copyValue = () => navigator.clipboard.writeText(valueText);
    if (valueText !== '')
      items.push({ label: 'Copy to clipboard', onClick: copyValue });
    if (items.length > 0 && pointedVars.length > 0)
      items.push('separator');
    pointedVars.forEach((lval) => {
      const [text, lvalMarker] = lval;
      const label = `Display values for ${text}`;
      const location = { fct: probe.fct, marker: lvalMarker };
      const onItemClick = () => model.addProbe(location);
      items.push({ label, onClick: onItemClick });
    });
    if (items.length > 0)
      items.push('separator');
    const remove = () => model.removeProbe(probe);
    const removeLabel = `Remove column for ${probe.code}`;
    items.push({ label: removeLabel, onClick: remove });
    if (items.length > 0) Dome.popupMenu(items);
  }

  return (
    <div
      className={className}
      style={style}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      onContextMenu={onContextMenu}
    >
      {contents}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Section
// --------------------------------------------------------------------------

interface TableSectionProps {
  fct: string;
  folded: boolean;
  foldable: boolean;
  onClick: () => void;
  byCallstacks: boolean;
  onCallstackClick: () => void;
  close: () => void;
}

function TableSection(props: TableSectionProps) {
  const { fct, foldable, folded, onClick } = props;
  const icon = folded ? 'ANGLE.RIGHT' :
    foldable ? 'ANGLE.DOWN' : 'TRIANGLE.RIGHT';
  return (
    <>
      <IconButton
        className="eva-fct-fold"
        size={10}
        offset={-1}
        icon={icon}
        enabled={foldable}
        onClick={onClick}
      />
      <Cell className="eva-fct-name">{fct}</Cell>
      <Filler />
      <IconButton
        icon="ITEMS.LIST"
        className="eva-probeinfo-button"
        selected={props.byCallstacks}
        title="Details by callstack"
        onClick={props.onCallstackClick}
      />
      <Inset />
      <IconButton
        icon="CROSS"
        className="eva-probeinfo-button"
        title="Close"
        onClick={props.close}
      />
    </>
  );
}

// --------------------------------------------------------------------------
// --- Table Row Header
// --------------------------------------------------------------------------

interface TableHeadProps {
  stackCalls: Callsite[];
  stackIndex: number | undefined;
  stackCount: number | undefined;
  onClick: () => void;
}

function makeStackTitle(calls: Callsite[]) {
  const cs = calls.slice(1);
  if (cs.length > 0)
    return `Callstack: ${cs.map((c) => c.callee).join(' \u2190 ')}`;
  return 'Callstack Details';
}

function TableHead(props: TableHeadProps) {
  const sk = props.stackIndex;
  const sc = props.stackCount;
  const hdClass = classes('eva-head', sc ? undefined : 'dome-hidden');
  const hdHeader = sk === undefined;
  const hdSummary = sk !== undefined && sk < 0;
  const hdNumber = sk === undefined ? 0 : 1 + sk;
  const hdTitle =
    hdHeader ? 'Callstack / Summary' :
      hdSummary ? 'Summary' : makeStackTitle(props.stackCalls);
  return (
    <div
      className={hdClass}
      title={hdTitle}
      onClick={props.onClick}
    >
      <div className="eva-phantom">{'\u2211'}{sc ?? '#'}</div>
      {hdHeader ? '#' : hdSummary ? '\u2211' : `${hdNumber}`}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Row
// --------------------------------------------------------------------------

interface TableRowProps {
  style: React.CSSProperties;
  index: number;
  data: ModelProp;
}

function TableRow(props: TableRowProps) {
  const { model } = props.data;
  const row = model.getRow(props.index);
  if (!row) return null;
  const { kind, probes } = row;
  if (kind === 'section') {
    const { fct } = row;
    if (!fct) return null;
    const folded = model.isFolded(fct);
    const foldable = model.isFoldable(fct);
    const byCallstacks = model.isByCallstacks(fct);
    return (
      <Hpack className="eva-function" style={props.style}>
        <TableSection
          fct={fct}
          folded={folded}
          foldable={foldable}
          onClick={() => model.setFolded(fct, !folded)}
          byCallstacks={byCallstacks}
          onCallstackClick={() => model.setByCallstacks(fct, !byCallstacks)}
          close={() => model.clearFunction(fct)}
        />
      </Hpack>
    );
  }
  const sk = row.stackIndex;
  const sc = row.stackCount;
  const cs = row.callstack;
  const calls = cs ? model.stacks.getCalls(cs) : [];
  const rowKind = `eva-${kind}`;
  const rowParity = sk !== undefined && sk % 2 === 1;
  const rowIndexKind =
    model.isSelectedRow(row) ? 'eva-row-selected' :
      model.isAlignedRow(row) ? 'eva-row-aligned' :
        rowParity ? 'eva-row-odd' : 'eva-row-even';
  const rowClass = classes('eva-row', rowKind, rowIndexKind);
  const onHeaderClick = () => model.setSelectedRow(row);
  const makeCell = (probe: Probe) => (
    <TableCell
      key={probe.marker}
      probe={probe}
      row={row}
      model={model}
    />
  );
  return (
    <Hpack style={props.style}>
      <div className={rowClass}>
        <TableHead
          stackIndex={sk}
          stackCount={sc}
          stackCalls={calls}
          onClick={onHeaderClick}
        />
        {probes.map(makeCell)}
      </div>
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

export interface Dimension {
  width: number;
  height: number;
}

export interface ValuesPanelProps extends Dimension, ModelProp {
  zoom: number;
}

export function ValuesPanel(props: ValuesPanelProps) {
  const { zoom, width, height, model } = props;
  // --- reset line cache
  const listRef = React.useRef<VariableSizeList>(null);
  const [rowCount, setRowCount] = React.useState(model.getRowCount());
  Dome.useEvent(model.laidout, () => {
    // The layout has changed, so the number of rows may also have changed.
    setRowCount(model.getRowCount());
    setImmediate(() => {
      const vlist = listRef.current;
      if (vlist) vlist.resetAfterIndex(0, true);
    });
  });
  // --- compute line height
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.dimension(model.getRowLines(k)),
    [model],
  );
  // --- compute layout
  const margin = WSIZER.capacity(width);
  const estimatedHeight = HSIZER.dimension(1);
  const [selection] = States.useSelection();
  React.useEffect(() => {
    const location = selection?.current;
    model.setLayout({ zoom, margin, location });
  });
  // --- render list
  return (
    <VariableSizeList
      ref={listRef}
      itemCount={rowCount}
      itemKey={model.getRowKey}
      itemSize={getRowHeight}
      estimatedItemSize={estimatedHeight}
      width={width}
      height={height}
      itemData={{ model }}
    >
      {TableRow}
    </VariableSizeList>
  );
}

// --------------------------------------------------------------------------
