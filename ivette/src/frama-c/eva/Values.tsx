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
import { RowKind } from './layout';
import { Probe } from './probes';
import { Model, getModelInstance } from './model';
import './style.css';

// --------------------------------------------------------------------------
// --- Use Model
// --------------------------------------------------------------------------

function useModel(): Model {
  const model = getModelInstance();
  Dome.useUpdate(model.signal);
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
  const stmt = rank ? `@S${rank}` : undefined;
  const { cols, rows } = sizeof(code);
  return (
    <Hpack className="eva-probe">
      <Label className="eva-probe-label">{label && `${label}:`}</Label>
      <div className="eva-probe-code">
        <SizedArea cols={cols} rows={rows}>{code}</SizedArea>
      </div>
      <Code className="eva-probe-stmt">{stmt}</Code>
      <IconButton
        className="eva-probe-button"
        visible={!!code}
        kind={transient ? 'positive' : 'negative'}
        icon={transient ? 'CIRC.CHECK' : 'CIRC.CLOSE'}
        onClick={() => { if (probe) probe.setTransient(!transient); }}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
      />
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Table Cell
// --------------------------------------------------------------------------

interface TableCellProps {
  kind: RowKind;
  probe: Probe;
}

const CELLPADDING = 4;

function TableCell(props: TableCellProps) {
  const model = useModel();
  const { probe, kind } = props;
  const minWidth = CELLPADDING + WSIZER.dimension(probe.minCols);
  const maxWidth = CELLPADDING + WSIZER.dimension(probe.maxCols);
  const style = { minWidth, maxWidth };
  let styling = 'dome-text-code';
  let contents: React.ReactNode = props.probe.marker;
  const { transient, label, code } = probe;
  switch (kind) {
    case 'probes':
      if (transient) {
        styling = 'dome-text-label';
        contents = '« Current »';
      } else if (label) {
        styling = 'dome-text-label';
        contents = label;
      } else {
        contents = <>{code}</>;
      }
      break;
    case 'values':
      contents = (
        model.cache.getValues(probe.marker).values
      );
      break;
  }
  const isFocused = model.getFocused() === probe;
  const className = classes(
    'eva-cell',
    styling,
    transient && 'eva-transient',
    !transient && isFocused && 'eva-focused',
  );
  return (
    <div className={className} style={style}>
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
  const contents = probes.map((probe) => (
    <TableCell
      key={probe.marker}
      kind={kind}
      probe={probe}
    />
  ));
  return (
    <Hpack className={className} style={props.style}>
      <div className="eva-row">
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
  const forceGridLayout = React.useCallback(
    () => {
      const vlist = listRef.current;
      if (vlist) vlist.resetAfterIndex(0, true);
    },
    [listRef],
  );
  // --- compute line height
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.dimension(model.getRowHeight(k)),
    [model],
  );
  // --- compute layout
  const margin = WSIZER.capacity(width);
  const rowHeight = HSIZER.dimension(1);
  const [selection] = States.useSelection();
  React.useEffect(() => {
    const target = Ast.jMarker(selection?.current?.marker);
    model.setLayout({ margin, target }, forceGridLayout);
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
