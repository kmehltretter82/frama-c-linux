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
import { IconButton } from 'dome/controls/buttons';
import { Hbox } from 'dome/layout/boxes';
import * as Forms from 'dome/layout/forms';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Eva from 'frama-c/plugins/eva/api/general';
import { EvaStatus } from 'frama-c/plugins/eva/components/AnalysisStatus';


export interface EvaToolsProps {
  remote: Forms.BufferController;
  iconSize: number;
}

export default function EvaTools(
  props: EvaToolsProps
): JSX.Element {
  const { remote, iconSize } = props;

  const evaComputed = States.useSyncValue(Eva.computationState);
  const countErrors = remote.getErrors();
  remote.resetNotified();

  const compute = (): void => { Server.send(Eva.compute, null); };
  const abort = (): void => { Server.send(Eva.abort, null); };
  const syncFromFC = (): void => { remote.reset(); };
  const syncToFC = (): void => { remote.commit(); };

  return (
    <Hbox className='eva-tools'>
      <Hbox className='eva-tools-actions'>
        <IconButton
          icon="MEDIA.PLAY"
          title="Launch Eva analysis"
          size={iconSize}
          disabled={evaComputed !== "not_computed"}
          onClick={compute}
        />
        <IconButton
          icon="MEDIA.STOP"
          title="Abort Eva analysis"
          size={iconSize}
          disabled={evaComputed !== "computing"}
          onClick={abort}
        />
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
      <Hbox className='eva-tools-status'>
        <EvaStatus iconSize={18} />
      </Hbox>
    </Hbox>
  );
}
