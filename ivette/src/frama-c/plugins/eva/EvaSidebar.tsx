/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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

import React from 'react';
import * as Forms from 'dome/layout/forms';
import * as Ivette from 'ivette';
import { useServerField } from 'frama-c/states';
import * as EVA from 'frama-c/plugins/eva/api/general';
import * as EvaDef from 'frama-c/plugins/eva/EvaDefinitions';
import { EvaFormOptions } from 'frama-c/plugins/eva/components/Form';
import EvaTools from './components/Tools';


export function EvaSideBar(): JSX.Element {
  const remote = Forms.useController();

  /* eslint-disable max-len */
  const precision = Forms.useBuffer(remote, useServerField(EVA.precision, 0));
  const main = Forms.useBuffer(remote, useServerField(EVA.main, ""));
  const libEntry = Forms.useBuffer(remote, useServerField(EVA.libEntry, false));
  const domains = Forms.useBuffer(remote, useServerField(EVA.Domains, ["cvalue"]));
  const domainsFiltered = Forms.useFilter(
    domains,
    EvaDef.domainsToKeyVal,
    EvaDef.KeyValToDomains,
    EvaDef.formEvaDomains
  );
  const WideningDelay = Forms.useBuffer(remote, useServerField(EVA.WideningDelay, 0));
  const ArrayPrecisionLevel = Forms.useBuffer(remote, useServerField(EVA.ArrayPrecisionLevel, 0));
  const LinearLevel = Forms.useBuffer(remote, useServerField(EVA.LinearLevel, 0));
  const EqualityCall = Forms.useBuffer(remote, useServerField(EVA.EqualityCall, "none"));
  const OctagonCall = Forms.useBuffer(remote, useServerField(EVA.OctagonCall, false));
  const sLevel = Forms.useBuffer(remote, useServerField(EVA.slevel, 0));
  const iLevel = Forms.useBuffer(remote, useServerField(EVA.ilevel, 0));
  const AutoLoopUnroll = Forms.useBuffer(remote, useServerField(EVA.AutoLoopUnroll, 0));
  const MinLoopUnroll = Forms.useBuffer(remote, useServerField(EVA.MinLoopUnroll, 0));
  const SplitReturn = Forms.useBuffer(remote, useServerField(EVA.SplitReturn, "none"));
  const HistoryPartitioning = Forms.useBuffer(remote, useServerField(EVA.HistoryPartitioning, 0));
  const AllocReturnsNull = Forms.useBuffer(remote, useServerField(EVA.AllocReturnsNull, false));
  const WarnPointerComparison = Forms.useBuffer(remote, useServerField(EVA.WarnPointerComparison, "none"));
  /* eslint-enable max-len */

  const evaFields = {
    "precision": {
      label: "Precision",
      step: 1, min: -1, max: 11,
      state: precision
    },
    "main": {
      label: "Main",
      state: main
    },
    "libEntry": {
      label: "LibEntry",
      state: libEntry
    },
    "domains": {
      label: "Domains",
      state: domainsFiltered
    },
    "sLevel": {
      label: "Slevel",
      step: 100, min: 0, max: 5000,
      state: sLevel
    },
    "iLevel": {
      label: "Ilevel",
      step: 10, min: 0, max: 256,
      state: iLevel
    },
    "AutoLoopUnroll": {
      label: "Auto loop unroll",
      step: 50, min: 0, max: 1024,
      state: AutoLoopUnroll
    },
    "SplitReturn": {
      label: "Split return",
      optionRadio: EvaDef.formEvaSplitReturn,
      state: SplitReturn
    },
    "AllocReturnsNull": {
      label: "Alloc returns null",
      state: AllocReturnsNull
    },
    "WarnPointerComparison": {
      label: "Warn pointer comparison",
      optionRadio: EvaDef.formEvaPointerComparison,
      state: WarnPointerComparison
    },
    "MinLoopUnroll": {
      label: "Min loop unroll",
      step: 1, min: 0, max: 4,
      state: MinLoopUnroll
    },
    "WideningDelay": {
      label: "Widening delay",
      step: 1, min: 1, max: 6,
      state: WideningDelay
    },
    "HistoryPartitioning": {
      label: "History partitioning",
      step: 1, min: 0, max: 2,
      state: HistoryPartitioning
    },
    "ArrayPrecisionLevel": {
      label: "PLevel",
      step: 100, min: 0, max: 5000,
      state: ArrayPrecisionLevel
    },
    "LinearLevel": {
      label: "Linear level",
      step: 5, min: 0, max: 220,
      state: LinearLevel
    },
    "EqualityCall": {
      label: "Equality call",
      optionRadio: EvaDef.formEvaEqualityCall,
      state: EqualityCall
    },
    "OctagonCall": {
      label: "Octagon call",
      state: OctagonCall
    },
  };

  return (
    <>
      <EvaTools
        remote={remote}
        iconSize={18}
      />
      <EvaFormOptions
        fields={evaFields}
      />
    </>
  );
}

Ivette.registerSidebar({
  id: 'frama-c.plugins.eva_sidebar',
  label: 'EVA',
  title: 'Eva Sidebar',
  children: <EvaSideBar />,
});
