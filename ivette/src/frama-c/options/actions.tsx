/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2025                                                */
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
import { Hbox } from 'dome/layout/boxes';
import { IconButton } from 'dome/controls/buttons';

// --------------------------------------------------------------------------
// --- Actions
// --------------------------------------------------------------------------

export function Remote({ iconSize, remote, onChange }: {
    iconSize: number;
    remote?: Forms.BufferController;
    onChange?: () => void;
  }
): React.JSX.Element | null {
  if(!remote) return null;

  const countErrors = remote.getErrors();
  remote.resetNotified();

  const syncFromFC = (): void => {
    remote.reset();
    onChange && onChange();
  };
  const syncToFC = (): void => {
    remote.commit();
    onChange && onChange();
  };

  return (
    <Hbox className='actions'>
      <IconButton
        icon="RELOAD"
        title="Reset form"
        size={iconSize}
        disabled={!remote.hasReset()}
        onClick={syncFromFC}
        />
      <IconButton
        icon="PUSH"
        title={"Commit changes"
          +
          (countErrors > 0 ?
          " : "+String(countErrors)+" error(s) in the form" : ""
          )
        }
        size={iconSize}
        kind={countErrors > 0 ? "warning" : "default"}
        disabled={!remote.hasCommit()}
        onClick={syncToFC}
      />
    </Hbox>
  );
}
