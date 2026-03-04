/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

import { useSyncState, useSyncValue } from 'frama-c/states';
import * as EvaParams from 'frama-c/kernel/api/parameters';
import * as EvaTaint from 'frama-c/plugins/eva/api/taint';
import { registerSidebar } from 'ivette';
import * as Toolbars from 'dome/frame/toolbars';
import { Label } from 'dome/controls/labels';
import { Checkbox, Button, IconButton } from 'dome/controls/buttons';
import * as AnalysisStatus from 'frama-c/plugins/eva/components/AnalysisStatus';
import { domainsToKeyVal } from 'frama-c/plugins/eva/EvaDefinitions';
import { SidebarTitle } from 'dome/frame/sidebars';

// --------------------------------------------------------------------------
// --- Globals selection
// ---------------------------------------------------------------------

const pinnedMessageId = 'EvaFilterTaint';

function addTaintMessage(names: string[], remove: () => void): void {
  const pinnedMessageButton =
    <IconButton
      icon='TRASH'
      title='Remove taint filter: show all taints'
      onClick={remove}
    />;
  const message = names.length === 1
    ? `Only taint "${names[0]}" is currently shown`
    : `Only taints ${names.map(n => `"${n}"`).join(', ')} are currently shown`;
  const pinnedMessage: Toolbars.PinnedMessage = {
    id: pinnedMessageId,
    message,
    actions: pinnedMessageButton
  };
  Toolbars.addPinnedMessage(pinnedMessage);
}

function delTaintMessage(): void {
  Toolbars.delPinnedMessage(pinnedMessageId);
}

function Taints({ taintNames }: { taintNames: string[] }): React.JSX.Element {
  const [current, setCurrent] = useSyncState(EvaTaint.currentTaint);
  const allTaintNamesSelected =
    // Selecting every taint is equivalent to not filtering at all.
    React.useMemo(() =>
      !!current && current.length > 0
      && taintNames.length > 0
      && taintNames.every((name) => current.includes(name)),
      [current, taintNames]
    );
  const selectedTaintNames =
    // Normalize the UI state so "all selected" behaves like "no filter".
    React.useMemo(
      () => allTaintNamesSelected ? [] : (current ?? []),
      [allTaintNamesSelected, current]
    );
  const hasSelection = selectedTaintNames.length > 0;

  React.useEffect(() => {
    if (allTaintNamesSelected)
      setCurrent([]);
  }, [allTaintNamesSelected, setCurrent]);

  React.useEffect(() => {
    if (hasSelection)
      addTaintMessage(selectedTaintNames, () => setCurrent([]));
    else
      delTaintMessage();
  }, [selectedTaintNames, hasSelection, setCurrent]);


  const onSelection = React.useCallback((v: string) => {
    const shownTaintNames = hasSelection ? selectedTaintNames : taintNames;
    if (shownTaintNames.includes(v))
      setCurrent(shownTaintNames.filter(n => n !== v));
    else
      setCurrent([...shownTaintNames, v]);
  }, [selectedTaintNames, hasSelection, setCurrent, taintNames]);

  return (<>
    <SidebarTitle label='Taints' >
      <Button
        label="Select All"
        disabled={!hasSelection}
        onClick={() => setCurrent([])}
      />
    </SidebarTitle>
    <div className="globals-scrollable-area eva-taint-list">
      {taintNames.map((name) => {
        const selected = selectedTaintNames.includes(name);
        const showCheck = selected || !hasSelection;
        return (
          <div key={name} className="eva-taint-row">
            <Checkbox
              label={name}
              title={name}
              value={showCheck}
              onChange={() => onSelection(name)}
            />
            { // Orange round marker: this taint is currently shown.
              showCheck && <span aria-hidden className="eva-taint-marker" />}
          </div>
        );
      })
      }
    </div>
  </>);
}

function NoTaintsMessage(
  { taintDomainEnabled }: { taintDomainEnabled: boolean }
): React.JSX.Element {
  const status = taintDomainEnabled ? 'computed' : 'not_computed';
  const title = taintDomainEnabled
    ? 'No taint results available.'
    : 'Taint analysis is disabled.';
  const message = taintDomainEnabled
    ? 'Nothing to display about taint analysis.'
    : 'Enable the taint domain and rerun Eva.';

  return (
    <div className={"eva-status eva-status-" + status}>
      <div className="eva-status-content">
        <div className="eva-status-message">{title}</div>
        <AnalysisStatus.StatusIcon size={50} status={status} />
        <Label className="eva-status-timer">{message}</Label>
      </div>
    </div>
  );
}

function TaintSidebar(): JSX.Element {
  const evaDomainsValue = useSyncValue(EvaParams.evaDomains);
  const evaDomains = React.useMemo(
    () => evaDomainsValue ?? 'cvalue',
    [evaDomainsValue]
  );
  const taintDomainEnabled = React.useMemo(
    () => Boolean(domainsToKeyVal(evaDomains).taint),
    [evaDomains]
  );
  const taintNamesValue = useSyncValue(EvaTaint.taintNames);
  const taintNames = React.useMemo(
    () => taintNamesValue ?? [],
    [taintNamesValue]
  );

  return (
    <AnalysisStatus.EvaReady>
      {taintNames.length > 0
        ? <Taints taintNames={taintNames} />
        : <NoTaintsMessage taintDomainEnabled={taintDomainEnabled} />}
    </AnalysisStatus.EvaReady>
  );
}

registerSidebar({
  id: 'fc.eva.filter.taints',
  label: 'Taints',
  icon: 'DROP.EMPTY',
  title: 'Taints',
  children: <TaintSidebar />
});

// --------------------------------------------------------------------------
