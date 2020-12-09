// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
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

import { callback, VState } from './vmodel';
import './style.css';

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

interface ProbePanelProps {
  transient?: boolean;
  label?: string;
  code?: string;
  onPersistent?: callback;
  onTransient?: callback;
}

function ProbePanel(props: ProbePanelProps) {
  const { transient = false, label, code } = props;
  return code ? (
    <Hpack className="eva-probe">
      <Label className="eva-probe-label">{label && `${label}:`}</Label>
      <Code className="eva-probe-code">{code}</Code>
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
// --- Values Panel
// --------------------------------------------------------------------------

interface ValuesPanelProps {
  age: number;
  vstate: VState;
}

function ValuesPanel(_props: ValuesPanelProps) {
  return (
    <Vfill>
      <AutoSizer>
        {({ width, height }) => (
          <div style={{ width, height }}>
            SIZE {width} x {height} (W/H)
          </div>
        )}
      </AutoSizer>
    </Vfill>
  );
}

// --------------------------------------------------------------------------
// --- Values Component
// --------------------------------------------------------------------------

// WARNING: MUST HAVE SINGLE USE
function useVState(): [number, VState] {
  const vstate = React.useMemo(() => new VState(), []);
  const [age, setAge] = React.useState(0);
  React.useEffect(() => vstate.bind(age, setAge), [vstate, age, setAge]);
  Server.useSignal(Values.changed, vstate.forceReload);
  return [age, vstate];
}

function ValuesComponent() {
  const [age, vstate] = useVState();
  const [selection] = States.useSelection();
  const marker = selection?.current?.marker;
  const probe = vstate.focus(marker);
  return (
    <>
      <TitleBar />
      <Vfill>
        <ProbePanel
          key="probe"
          transient={probe?.transient}
          label={probe?.label}
          code={probe?.code}
          onPersistent={probe?.setPersistent}
          onTransient={probe?.setTransient}
        />
        <ValuesPanel key="values" age={age} vstate={vstate} />
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
