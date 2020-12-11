// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import { VariableSizeList } from 'react-window';
import { Vfill, Hpack } from 'dome/layout/boxes';
import { Label, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';

// External Libs
import { AutoSizer } from 'react-virtualized';

// Frama-C
import { Component, TitleBar } from 'frama-c/LabViews';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values';

// Locals

import { callback, Size, VState } from './vmodel';
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
  return code ? (
    <Hpack className="eva-probe">
      <Label className="eva-probe-label">{label && `${label}:`}</Label>
      <Code className="eva-probe-code">{code}</Code>
      <Code className="eva-probe-stmt">{stmt}</Code>
      <IconButton
        kind={transient ? 'positive' : 'negative'}
        icon={transient ? 'CIRC.PLUS' : 'CIRC.CLOSE'}
        onClick={transient ? props.onPersistent : props.onTransient}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
      />
    </Hpack>
  ) : null;
}

// --------------------------------------------------------------------------
// --- Values Row
// --------------------------------------------------------------------------

interface ValuesRowProps {
  style: React.CSSProperties;
  index: number;
  data: VState;
}

function ValuesRow(props: ValuesRowProps) {
  const h = props.data.getRowHeight(props.index);
  return (<div style={props.style}>#{props.index} : {h}</div>);
}

// --------------------------------------------------------------------------
// --- Values Panel
// --------------------------------------------------------------------------

interface ValuesPanelProps extends Size {
  vstate: VState;
}

function ValuesPanel(props: ValuesPanelProps) {
  const { vstate, width, height } = props;
  const rows = vstate.layout(width);
  return (
    <VariableSizeList
      itemCount={rows}
      itemKey={vstate.getRowKey}
      itemSize={vstate.getRowHeight}
      width={width}
      height={height}
      itemData={vstate}
    >
      {ValuesRow}
    </VariableSizeList>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

// WARNING: MUST HAVE SINGLE USE
function useVState(): VState {
  const vstate = React.useMemo(() => new VState(), []);
  const [age, setAge] = React.useState(0);
  React.useEffect(() => vstate.bind(age, setAge), [vstate, age, setAge]);
  Server.useSignal(Values.changed, vstate.forceReload);
  return vstate;
}

function ValuesComponent() {
  const vstate = useVState();
  const [selection] = States.useSelection();
  const marker = selection?.current?.marker;
  const probe = vstate.focus(marker);
  const makeWindow = (size: Size) => (
    <ValuesPanel vstate={vstate} {...size} />
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
