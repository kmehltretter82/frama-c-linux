// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import * as Dome from 'dome';
import { classes } from 'dome/misc/utils';
import { VariableSizeList } from 'react-window';
import { Vfill, Hpack, Filler } from 'dome/layout/boxes';
import { Label, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as States from 'frama-c/states';

// Plugins
import * as Ast from 'frama-c/api/kernel/ast';

// Locals
import { SizedArea, HSIZER, WSIZER } from './sized';
import { sizeof } from './cells';
import { Row } from './layout';
import { Probe } from './probes';
import { Model, getModelInstance } from './model';
import './style.css';

// --------------------------------------------------------------------------
// --- Use Model
// --------------------------------------------------------------------------

function useModel(): Model {
  const model = getModelInstance();
  Dome.useUpdate(model.changed, model.laidout);
  return model;
}

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

function ProbeEditor() {
  const model = useModel();
  const probe = model.getFocused();
  const transient = probe?.transient ?? false;
  const label = probe?.label;
  const code = probe?.code;
  const rank = probe?.rank;
  const byCS = probe?.byCallstacks;
  const stmt = rank ? `@S${rank}` : undefined;
  const stacks = model.getStacks(probe).length;
  const { cols, rows } = sizeof(code);
  const width = WSIZER.dimension(cols) + 4;
  const height = HSIZER.dimension(rows) + 3;
  const visible = probe ? !!code : model.getRowCount() > 0;
  const visibility = visible ? 'visible' : 'hidden';
  return (
    <Hpack style={{ visibility }} className="eva-probe">
      <Label className="eva-probe-label">{label && `${label}:`}</Label>
      <div style={{ width, height }} className="eva-probe-code">
        <SizedArea cols={cols} rows={rows}>{code}</SizedArea>
      </div>
      <Code className="eva-probe-stmt">{stmt}</Code>
      <IconButton
        className="eva-probe-button"
        visible={byCS || stacks > 0}
        selected={byCS}
        icon="ITEMS.LIST"
        title={`Details by callstack (${stacks})`}
        onClick={() => { if (probe) probe.setByCallstacks(!byCS); }}
      />
      <IconButton
        className="eva-probe-button"
        kind={transient ? 'selected' : 'warning'}
        icon={transient ? 'CIRC.CHECK' : 'CIRC.CLOSE'}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
        onClick={() => { if (probe) probe.setTransient(!transient); }}
      />
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Table Cell Layout
// --------------------------------------------------------------------------

interface TableCellProps {
  probe: Probe;
  row: Row;
}

const CELLPADDING = 4;

function TableCell(props: TableCellProps) {
  const model = useModel();
  const [selection, setSelection] = States.useSelection();
  const { probe, row } = props;
  const { kind, callstack } = row;
  const minWidth = CELLPADDING + WSIZER.dimension(probe.minCols);
  const maxWidth = CELLPADDING + WSIZER.dimension(probe.maxCols);
  const style = { width: minWidth, maxWidth };
  let contents: React.ReactNode = props.probe.marker;
  const { transient } = probe;

  switch (kind) {

    // ---- Probe Contents
    case 'probes':
      if (transient) {
        contents = <span className="dome-text-label">« Probe »</span>;
      } else {
        const { rank, code, label } = probe;
        const atpoint = rank && (
          <span className="eva-probe-stmt">@S{rank}</span>
        );
        contents = (
          <span className="dome-text-label">{label ?? code}{atpoint}</span>
        );
      }
      break;

    // ---- Values Contents
    case 'values':
    case 'callstack':
      {
        const { values } = model.values.getValues(probe.marker, callstack);
        const { cols, rows } = sizeof(values);
        contents = (
          <SizedArea cols={cols} rows={rows}>
            {values}
          </SizedArea>
        );
      }
      break;

  }

  // --- Cell Packing
  const isFocused = model.getFocused() === probe;
  const className = classes(
    'eva-cell',
    transient && 'eva-transient',
    !transient && isFocused && 'eva-focused',
  );
  const onClick = () => {
    if (probe) {
      const fct = selection?.current?.function;
      const location = { function: fct, marker: probe.marker };
      setSelection({ location });
    }
  };
  return (
    <div
      className={className}
      style={style}
      onClick={onClick}
    >
      {contents}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Table Row
// --------------------------------------------------------------------------

interface TableRowProps {
  style: React.CSSProperties;
  index: number;
}

function TableRow(props: TableRowProps) {
  const model = useModel();
  const row = model.getRow(props.index);
  if (!row) return null;
  const { kind, probes } = row;
  const className = `eva-${kind}`;
  const sk = row.stackIndex;
  const header = row.stacks && (
    <div className="eva-cell eva-stack">
      {sk === undefined ? '#' : `${1 + sk}`}
    </div>
  );
  const contents = probes.map((probe) => (
    <TableCell
      key={probe.marker}
      probe={probe}
      row={row}
    />
  ));
  return (
    <Hpack className={className} style={props.style}>
      <div className="eva-row">
        {header}
        {contents}
      </div>
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface Dimension {
  width: number;
  height: number;
}

function ValuesPanel(props: Dimension) {
  const model = useModel();
  const { width, height } = props;
  // --- reset line cache
  const listRef = React.useRef<VariableSizeList>(null);
  Dome.useEvent(model.laidout, () => {
    const vlist = listRef.current;
    if (vlist) vlist.resetAfterIndex(0, true);
  });
  // --- compute line height
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.dimension(model.getRowLines(k)),
    [model],
  );
  // --- compute layout
  const margin = WSIZER.capacity(width);
  const rowHeight = HSIZER.dimension(1);
  const [selection] = States.useSelection();
  React.useEffect(() => {
    const target = Ast.jMarker(selection?.current?.marker);
    model.setLayout({ margin, target });
  });
  // --- render list
  return (
    <VariableSizeList
      ref={listRef}
      itemCount={model.getRowCount()}
      itemKey={model.getRowKey}
      itemSize={getRowHeight}
      estimatedItemSize={rowHeight}
      width={width}
      height={height}
      itemData={model}
    >
      {TableRow}
    </VariableSizeList>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

function ValuesComponent() {
  return (
    <>
      <TitleBar />
      <Vfill>
        <ProbeEditor />
        <Vfill>
          <AutoSizer>
            {(dim: Dimension) => <ValuesPanel {...dim} />}
          </AutoSizer>
        </Vfill>
      </Vfill>
    </>
  );
}

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="frama-c.values"
    label="Eva Values"
    title="Values inferred by the Eva analysis"
  >
    <ValuesComponent />
  </Component>
);

// --------------------------------------------------------------------------
