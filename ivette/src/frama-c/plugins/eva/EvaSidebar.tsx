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
import { useServerField, State } from 'frama-c/states';
import * as Params from 'frama-c/kernel/api/parameters';
import * as EvaDef from 'frama-c/plugins/eva/EvaDefinitions';
import { EvaFormOptions } from 'frama-c/plugins/eva/components/Form';
import EvaTools from './components/Tools';


export function EvaSideBar(): JSX.Element {
  const remote = Forms.useController();

  function useField<A>(state: State<A>, defaultValue: A) : Forms.FieldState<A> {
    return Forms.useBuffer(remote, useServerField(state, defaultValue));
  }

  const precision = useField(Params.evaPrecision, 0);
  const main = useField(Params.main, "");
  const libEntry = useField(Params.libEntry, false);
  const domains = useField(Params.evaDomains, "cvalue");
  const domainsFiltered = Forms.useFilter(
    domains,
    EvaDef.domainsToKeyVal,
    EvaDef.KeyValToDomains,
    EvaDef.formEvaDomains
  );
  const WideningDelay = useField(Params.evaWideningDelay, 0);
  const ArrayPrecisionLevel = useField(Params.evaPlevel, 0);
  const LinearLevel = useField(Params.evaSubdivideNonLinear, 0);
  const EqualityCall = useField(Params.evaEqualityThroughCalls, "none");
  const OctagonCall = useField(Params.evaOctagonThroughCalls, false);
  const sLevel = useField(Params.evaSlevel, 0);
  const iLevel = useField(Params.evaIlevel, 0);
  const AutoLoopUnroll = useField(Params.evaAutoLoopUnroll, 0);
  const MinLoopUnroll = useField(Params.evaMinLoopUnroll, 0);
  const SplitReturn = useField(Params.evaSplitReturn, "none");
  const HistoryPartitioning = useField(Params.evaPartitionHistory, 0);
  const AllocReturnsNull = useField(Params.evaAllocReturnsNull, false);
  const WarnPointerComparison =
    useField(Params.evaWarnUndefinedPointerComparison, "none");

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
