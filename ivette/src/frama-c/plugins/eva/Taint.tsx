/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';

import { Item, SidebarTitle } from 'dome/frame/sidebars';

import * as Server from 'frama-c/server';
import { computationState } from 'frama-c/plugins/eva/api/analysis';
import { useSyncState, useSyncValue } from 'frama-c/states';
import { currentTaint, getTaintNames } from 'frama-c/plugins/eva/api/taint';
import {
  PinnedMessage, addPinnedMessage, Button, delPinnedMessage
} from 'dome/frame/toolbars';
import { Icon } from 'dome/controls/icons';
import { registerSidebar } from 'ivette';
import { IconButton } from 'dome/controls/buttons';

// --------------------------------------------------------------------------
// --- Globals selection
// ---------------------------------------------------------------------

async function getTaints(
  callback: React.Dispatch<React.SetStateAction<string[]>>
): Promise<void> {
  const taints = await Server.send(getTaintNames, null);
  callback(taints);
}

const pinnedMessageId = 'EvaFilterTaint';

function addTaintMessage(name: string, remove: () => void): void {
  const pinnedMessageButton =
    <IconButton
      icon='TRASH'
      title='Remove taint filter: show all taints'
      onClick={remove}
    />;
  const pinnedMessage: PinnedMessage = {
    id: pinnedMessageId,
    message: `Only taint "${name}" is currently shown`,
    actions: pinnedMessageButton
  };
  addPinnedMessage(pinnedMessage);
}

function delTaintMessage(): void {
  delPinnedMessage(pinnedMessageId);
}

function Taints(): React.JSX.Element {
  const scrollableArea = React.useRef<HTMLDivElement>(null);
  const evaStatus = useSyncValue(computationState);
  const [current, setCurrent] = useSyncState(currentTaint);
  const [taints, setTaints] = React.useState<string[]>([]);

  React.useEffect(() => {
    if (current)
      addTaintMessage(current, () => setCurrent(''));
    else
      delTaintMessage();
  }, [current, setCurrent]);

  React.useEffect(() => {
    if(evaStatus === 'computed' || evaStatus === 'aborted')
      getTaints(setTaints);
    else
      setTaints([]);
  }, [evaStatus]);

  const onSelection = React.useCallback((v: string) => {
    if(v === current) setCurrent('');
    else setCurrent(v);
  }, [current, setCurrent]);

  return (<>
    <SidebarTitle label='Taints' >
      <Button
        label='Select All'
        disabled={current===''}
        onClick={() => setCurrent('')}
      />
    </SidebarTitle>
    <div ref={scrollableArea} className="globals-scrollable-area">
      { taints.map((name) =>
          <Item
            key={name}
            title={name}
            label={name}
            selected={current === name}
            onSelection={() => onSelection(name)}
          >{(current === name || current === '') &&
              <Icon id='CHECK' kind='positive' />
          }</Item>
        )
      }
    </div>
  </>);
}

registerSidebar({
  id: 'fc.eva.filter.taints',
  label: 'Taints',
  icon: 'DROP.EMPTY',
  title: 'Taints',
  children: <Taints />
});

// --------------------------------------------------------------------------
