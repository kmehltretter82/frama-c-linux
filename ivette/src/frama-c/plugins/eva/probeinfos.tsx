/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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
import { ModelProp } from './model';
import { Stmt } from './valueinfos';

// --------------------------------------------------------------------------
// --- Probe Editor
// --------------------------------------------------------------------------

function ProbeEditor(props: ModelProp) {
  const { model } = props;
  const probe = model.getFocused();
  if (!probe || !probe.code) return null;
  const { label } = probe;
  const { code } = probe;
  const { stmt, marker } = probe;
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
      <Code><Stmt stmt={stmt} marker={marker} /></Code>
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

export function ProbeInfos(props: ModelProp) {
  const { model } = props;
  const probe = model.getFocused();
  const fct = probe?.fct;
  const byCS = fct ? model.isByCallstacks(fct) : false;
  const effects = probe ? probe.effects : false;
  const condition = probe ? probe.condition : false;
  const summary = fct ? model.stacks.getSummary(fct) : false;
  const vcond = model.getVcond();
  const vstmt = model.getVstmt();
  return (
    <Hpack className="eva-probeinfo">
      <ProbeEditor model={model} />
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
          selected={vcond === 'Cond'}
          title="Show values in all conditions"
          onClick={() => model.setVcond('Cond')}
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
            model.setVstmt(vstmt === 'After' ? 'Before' : 'After');
          }}
        />
      </ButtonGroup>
    </Hpack>
  );
}

// --------------------------------------------------------------------------
