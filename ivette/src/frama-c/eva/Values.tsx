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
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

// Plugins
import * as Ast from 'frama-c/api/kernel/ast';
import * as Values from 'frama-c/api/plugins/eva/values';

// Locals
import { SizedArea, HSIZER, WSIZER } from './sized';
import { callback, sizeof } from './cells';
import { RowKind } from './layout';
import { Probe } from './probes';
import { Model } from './model';
import './style.css';

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

interface ProbePanelProps {
  transient?: boolean;
  label?: string;
  code?: string;
  stmt?: string;
  onPersistent?: callback;
  onTransient?: callback;
}

function ProbePanel(props: ProbePanelProps) {
  const { transient = false, label, code, stmt } = props;
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
        onClick={transient ? props.onPersistent : props.onTransient}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
      />
      <Filler />
    </Hpack>
  );
}

// --------------------------------------------------------------------------
// --- Table Update
// --------------------------------------------------------------------------

const ChangeEvent = new Dome.Event<void>('eva-changed');
const forceUpdate = () => setImmediate(ChangeEvent.emit);

// --------------------------------------------------------------------------
// --- Table Cell
// --------------------------------------------------------------------------

interface TableCellProps {
  kind: RowKind;
  probe: Probe;
  model: Model;
}

function TableCell(props: TableCellProps) {
  Dome.useUpdate(ChangeEvent);
  const { probe, kind, model } = props;
  const minWidth = WSIZER.dimension(probe.minCols);
  const maxWidth = WSIZER.dimension(probe.maxCols);
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
      contents = 'VALUES';
  }
  const className = classes(
    'eva-cell',
    styling,
    transient && 'eva-transient',
    !transient && model.isFocused(probe) && 'eva-focused',
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
  data: Model;
}

function TableRow(props: TableRowProps) {
  Dome.useUpdate(ChangeEvent);
  const { data: model, index } = props;
  const row = model.getRow(index);
  if (!row) return null;
  const { kind, probes } = row;
  const className = `eva-${kind}`;
  const contents = probes.map((probe) => (
    <TableCell
      key={probe.marker}
      kind={kind}
      probe={probe}
      model={model} />
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

interface ValuesPanelProps extends Dimension {
  model: Model;
}

function ValuesPanel(props: ValuesPanelProps) {
  const { model, width, height } = props;
  const listRef = React.useRef<VariableSizeList>(null);
  // --- reset line cache
  const forceLayout = React.useCallback(
    () => {
      const vlist = listRef.current;
      if (vlist) vlist.resetAfterIndex(0, true);
    }, [listRef],
  );
  // --- compute line height
  const getRowHeight = React.useCallback(
    (k: number) => HSIZER.dimension(model.getRowHeight(k)),
    [model],
  );
  // --- compute layout
  const margin = WSIZER.capacity(width);
  const rowHeight = HSIZER.dimension(1);
  model.setLayout({ margin }, forceLayout);
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
  const model = React.useMemo(() => new Model(forceUpdate), []);
  Dome.useUpdate(ChangeEvent);
  Server.useSignal(Values.changed, forceUpdate);
  const [selection] = States.useSelection();
  const target = Ast.jMarker(selection?.current?.marker);
  const probe = model.focus(target);
  const makeWindow = (size: Dimension) => (
    <ValuesPanel model={model} {...size} />
  );
  const rank = probe?.rank;
  const stmt = rank ? `@S${rank}` : undefined;
  return (
    <>
      <TitleBar />
      <Vfill>
        <ProbePanel
          transient={probe?.transient}
          label={probe?.label}
          code={probe?.code}
          stmt={stmt}
          onPersistent={probe?.setPersistent}
          onTransient={probe?.setTransient}
        />
        <Vfill>
          <AutoSizer>
            {makeWindow}
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
