// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// React & Dome
import React from 'react';
import { Hpack, Filler } from 'dome/layout/boxes';
import { Label, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { ButtonGroup, Button } from 'dome/frame/toolbars';

// Frama-C
import * as States from 'frama-c/states';

// Locals
import { SizedArea } from './sized';
import { sizeof } from './cells';
import { useModel } from './model';
import { Stmt } from './valueinfos';

// --------------------------------------------------------------------------
// --- Probe Editor
// --------------------------------------------------------------------------

function ProbeEditor() {
  const model = useModel();
  const probe = model.getFocused();
  if (!probe || !probe.code) return null;
  const { label } = probe;
  const { code } = probe;
  const { stmt } = probe;
  const { rank } = probe;
  const byCS = probe.byCallstacks;
  const stacks = model.getStacks(probe);
  const stackable = byCS || stacks.length > 1;
  const { cols, rows } = sizeof(code);
  const { transient } = probe;
  const { zoomed } = probe;
  const { zoomable } = probe;
  return (
    <>
      <Label className="eva-probeinfo-label">{label}</Label>
      <div className="eva-probeinfo-code">
        <SizedArea cols={cols} rows={rows}>{code}</SizedArea>
      </div>
      <Code><Stmt stmt={stmt} rank={rank} /></Code>
      <IconButton
        icon="ITEMS.LIST"
        className="eva-probeinfo-button"
        display={stackable}
        selected={byCS}
        title={`Details by callstack (${stacks})`}
        onClick={() => { if (probe) probe.setByCallstacks(!byCS); }}
      />
      <IconButton
        icon="SEARCH"
        className="eva-probeinfo-button"
        display={zoomable}
        selected={zoomed}
        onClick={() => { if (probe) probe.setZoomed(!zoomed); }}
      />
      <IconButton
        icon="PIN"
        className="eva-probeinfo-button"
        selected={!transient}
        title={transient ? 'Make the probe persistent' : 'Release the probe'}
        onClick={() => {
          if (probe) {
            if (transient) probe.setPersistent();
            else probe.setTransient();
          }
        }}
      />
      <IconButton
        icon="CIRC.CLOSE"
        className="eva-probeinfo-button"
        display={!transient}
        title="Discard the probe"
        onClick={() => {
          if (probe) {
            probe.setTransient();
            const p = probe.next ?? probe.prev;
            if (p) setImmediate(() => {
              States.setSelection({ fct: p.fct, marker: p.marker });
            });
            else model.clearSelection();
          }
        }}
      />
    </>
  );
}

// --------------------------------------------------------------------------
// --- Probe Panel
// --------------------------------------------------------------------------

export function ProbeInfos() {
  const model = useModel();
  const probe = model.getFocused();
  const fct = probe?.fct;
  const byCS = probe?.byCallstacks;
  const effects = probe ? probe.effects : false;
  const condition = probe ? probe.condition : false;
  const summary = fct ? model.stacks.getSummary(fct) : false;
  const vcond = model.getVcond();
  const vstmt = model.getVstmt();
  return (
    <Hpack className="eva-probeinfo">
      <ProbeEditor />
      <Filler />
      <ButtonGroup
        enabled={!!probe}
        className="eva-probeinfo-state"
      >
        <Button
          label={'\u2211'}
          title="Show Callstacks Summary"
          selected={summary}
          visible={byCS}
          onClick={() => { if (fct) model.stacks.setSummary(fct, !summary); }}
        />
        <Button
          visible={condition}
          label="C"
          selected={vcond === 'Here'}
          title="Show values in all conditions"
          onClick={() => model.setVcond('Here')}
        />
        <Button
          visible={condition || vcond === 'Then'}
          selected={vcond === 'Then'}
          enabled={condition}
          label="T"
          value="Then"
          title="Show reduced values when condition holds (Then)"
          onClick={() => model.setVcond('Then')}
        />
        <Button
          visible={condition || vcond === 'Else'}
          selected={vcond === 'Else'}
          enabled={condition}
          label="E"
          value="Else"
          title="Show reduced values when condition does not hold (Else)"
          onClick={() => model.setVcond('Else')}
        />
        <Button
          visible={condition || effects}
          selected={vstmt === 'After'}
          label="A"
          value="After"
          title="Show values after/before statement effects"
          onClick={() => {
            model.setVstmt(vstmt === 'After' ? 'Here' : 'After');
          }}
        />
      </ButtonGroup>
    </Hpack>
  );
}

// --------------------------------------------------------------------------
