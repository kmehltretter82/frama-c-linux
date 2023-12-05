/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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
import { classes } from 'dome/misc/utils';
import { IconButton } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import { Vbox, Hbox } from 'dome/layout/boxes';
import * as States from 'frama-c/states';
import * as TIP from 'frama-c/plugins/wp/api/tip';
import * as TAC from 'frama-c/plugins/wp/api/tac';

type Node = TIP.node | undefined;
type Tactic = TAC.tactic | undefined;

/* -------------------------------------------------------------------------- */
/* --- Tactical View                                                      --- */
/* -------------------------------------------------------------------------- */

interface TacticalProps extends TAC.tacticalData {
  node: Node;
  selected: Tactic;
  setSelected: (tac: Tactic) => void;
}

function Tactical(props: TacticalProps): JSX.Element | null {
  const { id, status, selected, setSelected } = props;
  if (status === 'NotApplicable') return null;
  const onSelect = (): void => setSelected(id);
  const onPlay = (): void => { return; };
  const className = classes(
    'dome-color-frame wp-tactical-item',
    selected===id && 'selected',
  );
  return (
    <Hbox
      className={className}
      onClick={onSelect}
      onDoubleClick={onPlay}
    >
      <Label className='wp-tactical-cell' {...props}/>
      <IconButton
        icon='MEDIA.PLAY'
        title='Apply Tactic'
        kind='positive'
        enabled={status==='Applicable'}
        onClick={onPlay} />
    </Hbox>
  );
}

/* -------------------------------------------------------------------------- */
/* --- All Tactics View                                                   --- */
/* -------------------------------------------------------------------------- */

export interface TacticsProps {
  node: Node;
}

export function Tactics(props: TacticsProps): JSX.Element {
  const { node } = props;
  const [selected, setSelected] = React.useState<Tactic>();
  const tactics = States.useSyncArrayData(TAC.tactical);
  return (
    <Vbox className='wp-tactical-view'>
      {tactics.map(tac => (
        <Tactical
          key={tac.id}
          node={node}
          selected={selected}
          setSelected={setSelected}
          {...tac} />
      ))}
    </Vbox>
  );
}

/* -------------------------------------------------------------------------- */
