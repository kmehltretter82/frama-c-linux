/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';
import { IconButton, Spinner } from 'dome/controls/buttons';
import { SidebarTitle } from 'dome/frame/sidebars';
import { Hbox, Vbox } from 'dome/layout/boxes';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Params from 'frama-c/kernel/api/parameters';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from './tip';

function Tools(): JSX.Element {
  const { running } = TIP.useServerActivity();
  const run = (): void => { Server.send(WP.startProofs, null); };
  const stop = (): void => { Server.send(WP.cancelProofTasks, null); };
  return (
    <Hbox>
      <IconButton
        icon="MEDIA.PLAY"
        title="Start WP"
        onClick={run}
        disabled={running}
      />
      <IconButton
        icon="MEDIA.STOP"
        title="Stop proof tasks"
        onClick={stop}
        enabled={running}
      />
    </Hbox>
  );
}

interface ProverConfig {
  prover: WP.prover;
  up: boolean;
  name: string;
}

function Prover(props: ProverConfig): JSX.Element {
  const { prover, up, name } = props;
  const [checked, setChecked] = React.useState(up);

  const onClick = () : void => {
    setChecked(!checked);
    Server.send(WP.setProverState, [prover, !checked]);
  };
  const icon = checked ? 'SWITCH.ON' : 'SWITCH.OFF';
  const iconKind = checked ? 'positive' : 'default';
  return (
    <Hbox key={prover}>
      <Icon id={icon} kind={iconKind} onClick={onClick} />
      <Label label={name} title={name} />
    </Hbox>
  );
}

export function SideBar(): JSX.Element {
  /* const rte = Params.wpRte; */
  const [timeout, setTimeout] = States.useSyncState(Params.wpTimeout);
  const [processes, setProcesses] = States.useSyncState(Params.wpPar);

  const provers = States.useSyncValue(WP.provers) ?? [];
  const proversInfo = States.useSyncArrayGetter(WP.ProverInfos);

  const auto = provers.filter((p) => proversInfo(p)?.auto);
  const inter = provers.filter((p) => !proversInfo(p)?.auto);

  return (
    <>
      <SidebarTitle label='Weakest Precondition'>
        <Tools />
      </SidebarTitle>
      <Vbox>
        <Label label='Provers Configuration' />
        <Vbox>
          <Label label='Timeout' icon='TUNINGS' >
            <Spinner
              className="wp-config-field wp-config-spinner"
              value={timeout}
              vmin={0}
              vstep={1}
              onChange={setTimeout}
            />
          </Label>
          <Label label='Processes' icon='SETTINGS'>
            <Spinner
              className="wp-config-field wp-config-spinner"
              value={processes}
              vmin={0}
              vstep={1}
              onChange={setProcesses}
            />
          </Label>
        </Vbox>
        <Label label='Automatic Provers' />
        {
          auto.map((p) =>
            <Prover
              key={p}
              prover={p}
              up={proversInfo(p)?.active ?? false}
              name={proversInfo(p)?.name ?? ''}
            />
          )
        }
        <Label label='Interactive Provers' />
        {
          inter.map((p) =>
            <Prover
              key={p}
              prover={p}
              up={proversInfo(p)?.active ?? false}
              name={proversInfo(p)?.name ?? ''}
            />
          )
        }
      </Vbox>
    </>
  );
}
