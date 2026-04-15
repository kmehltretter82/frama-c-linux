/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import * as Utils from 'dome/misc/utils';
import * as Forms from 'dome/layout/forms';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';
import { showHelp } from 'dome/help';
import {
  Checkbox,
  Button,
  SelectMenu,
  Spinner,
  IconButton,
} from 'dome/controls/buttons';
import { SidebarTitle } from 'dome/frame/sidebars';
import { DivProps, Hbox, Hfill, Vbox } from 'dome/layout/boxes';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Params from 'frama-c/kernel/api/parameters';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from './tip';

function Section(p: Forms.SectionProps): JSX.Element {
  return (
    <Forms.Section
      label={p.label}
      unfold
    >
      {p.children}
    </Forms.Section>
  );
}

interface SidebarBlockProps extends DivProps {
  title: string;
  titleButtons?: JSX.Element[];
  foldable?: boolean;
}

function SidebarBlock(props: SidebarBlockProps): JSX.Element {
  const { children, title, titleButtons, foldable = false, ...others } = props;

  const [open, setOpen] = React.useState(!foldable);

  const ftitle = title + (open ? '' : ' ...');
  const ititle = foldable ? (open ? 'ANGLE.DOWN' : 'ANGLE.RIGHT') : undefined;
  const onClick = (): void => { setOpen(!open); };

  return (
    <Vbox className={Utils.classes('wp-sidebar-block')} {...others}>
      <Hbox>
        <Label
          label={ftitle}
          className={Utils.classes('wp-sidebar-block-title')}
          icon={ititle}
          onClick={onClick}
        />
        <Hfill />
        {titleButtons}
      </Hbox>
      {(!foldable || open) && children}
    </Vbox>
  );
}

function Tools(): JSX.Element {
  const { running } = TIP.useServerActivity();
  const run = (): void => { Server.send(WP.startProofs, null); };
  const stop = (): void => { Server.send(WP.cancelProofTasks, null); };
  const help = (): void => { showHelp('wp'); };
  return (
    <Hbox>
      <Button
        icon='MEDIA.PLAY'
        title='Start WP'
        onClick={run}
        disabled={running}
      />
      <Button
        icon='MEDIA.STOP'
        title='Stop proof tasks'
        onClick={stop}
        enabled={running}
      />
      <Button
        icon='HELP'
        title='WP documentation'
        onClick={help}
      />
    </Hbox>
  );
}

interface ProverConfig {
  prover: WP.prover;
  up: boolean;
  name: string;
  version: string;
}

function Prover(props: ProverConfig): JSX.Element {
  const { prover, up, name, version } = props;
  const [checked, setChecked] = React.useState(up);

  const onClick = (): void => {
    setChecked(!checked);
    Server.send(WP.setProverState, [prover, !checked]);
  };
  const icon = checked ? 'SWITCH.ON' : 'SWITCH.OFF';
  const iconKind = checked ? 'positive' : 'default';
  const className = Utils.classes('wp-sidebar-prover-label');
  const label = name + ' (' + version + ')';
  return (
    <Hbox key={prover}>
      <Icon
        id={icon}
        kind={iconKind}
        onClick={onClick}
        size={16}
      />
      <Label label={label} className={className} />
    </Hbox>
  );
}

function CacheSelector(): JSX.Element {
  const [cacheMode, setCacheMode] = States.useSyncState(WP.cacheMode);
  const { help } =
    States.useRequestStable(Params.getParameterInfo, '-wp-cache');
  const onChange = (value: string | undefined): void => {
    const mode =
      value
        ? WP.CacheMode[value as keyof typeof WP.CacheMode]
        : undefined;
    if (mode)
      setCacheMode(mode);
  };
  const options =
    (Object.keys(WP.CacheMode) as Array<keyof typeof WP.CacheMode>)
      .map((value) =>
        <option key={value} value={value}>{value}</option>
      );
  return (
    <>
      <SelectMenu
        value={cacheMode}
        onChange={onChange}
      >{options}</SelectMenu>
      <IconButton icon='HELP' title={help} />
    </>
  );
}

function InteractiveSelector(): JSX.Element {
  const [inter, setInter] = States.useSyncState(WP.interactiveMode);
  const { help } =
    States.useRequestStable(Params.getParameterInfo, '-wp-interactive');
  const onChange = (value: string | undefined): void => {
    const mode =
      value
        ? WP.InteractiveMode[value as keyof typeof WP.InteractiveMode]
        : undefined;
    if (mode)
      setInter(mode);
  };
  const options =
    (Object.keys(WP.InteractiveMode) as Array<keyof typeof WP.InteractiveMode>)
      .map((value) =>
        <option key={value} value={value}>{value}</option>
      );
  return (
    <Label label='Mode'>
      <SelectMenu
        value={inter}
        onChange={onChange}
      >{options}</SelectMenu>
      <IconButton icon='HELP' title={help} />
    </Label>
  );
}

function TipSelector(): JSX.Element {
  const [tipMode, setTipMode] = States.useSyncState(WP.tipMode);
  const { help } =
    States.useRequestStable(Params.getParameterInfo, '-wp-script');
  const onChange = (value: string | undefined): void => {
    const mode =
      value
        ? WP.TipMode[value as keyof typeof WP.TipMode]
        : undefined;
    if (mode)
      setTipMode(mode);
  };
  const options =
    (Object.keys(WP.TipMode) as Array<keyof typeof WP.TipMode>)
      .map((value) =>
        <option key={value} value={value}>{value}</option>
      );
  return (
    <Label label='Mode'>
      <SelectMenu
        value={tipMode}
        onChange={onChange}
      >{options}</SelectMenu>
      <IconButton icon='HELP' title={help} />
    </Label>
  );
}

function ProversConfiguration(): JSX.Element {
  const [timeout = 0, setTimeout] = States.useSyncState(Params.wpTimeout);
  const [processes = 0, setProcesses] = States.useSyncState(Params.wpPar);

  const provers = States.useSyncValue(WP.provers) ?? [];
  const proversInfo = States.useSyncArrayGetter(WP.ProverInfos);

  const autoPrvs = provers.filter((p) => proversInfo(p)?.auto);
  const interPrvs = provers.filter((p) => !proversInfo(p)?.auto);

  const [scripts = false, setScripts] = States.useSyncState(WP.scripts);
  const [strategies = false, setStrats] = States.useSyncState(WP.strategies);

  return (
    <Section label='Provers Configuration' >
      <SidebarBlock title='General configuration'>
        <Label label='Timeout' icon='CLOCK' >
          <Spinner
            className="wp-config-field wp-config-spinner"
            value={timeout || 0}
            vmin={0}
            vstep={1}
            onChange={setTimeout}
          />
        </Label>
        <Label label='Processes' icon='SETTINGS'>
          <Spinner
            className="wp-config-field wp-config-spinner"
            value={processes || 0}
            vmin={0}
            vstep={1}
            onChange={setProcesses}
          />
        </Label>
        <Label label='Cache' icon='SERVER'>
          <CacheSelector />
        </Label>
      </SidebarBlock>
      <SidebarBlock title='Automatic Provers'>
        {
          autoPrvs.length !== 0 ?
            autoPrvs.map((p) =>
              <Prover
                key={p}
                prover={p}
                up={proversInfo(p)?.active ?? false}
                name={proversInfo(p)?.name ?? ''}
                version={proversInfo(p)?.version ?? ''}
              />
            )
            :
            <Label
              label='No automatic provers detected'
              icon='WARNING'
              kind='negative'
            />
        }
      </SidebarBlock>
      <SidebarBlock
        title='Interactive Provers'
        display={interPrvs.length !== 0}
      >
        <InteractiveSelector />
        {
          interPrvs.map((p) =>
            <Prover
              key={p}
              prover={p}
              up={proversInfo(p)?.active ?? false}
              name={proversInfo(p)?.name ?? ''}
              version={proversInfo(p)?.version ?? ''}
            />
          )
        }
      </SidebarBlock>
      <SidebarBlock
        title='No Interactive Provers'
        display={interPrvs.length === 0}
      />
      <SidebarBlock title='Proof Strategies'>
        <TipSelector />
        <Checkbox
          label='Use scripts'
          onChange={setScripts}
          value={scripts}
        />
        <Checkbox
          label='Use strategies'
          onChange={setStrats}
          value={strategies}
        />
      </SidebarBlock>
    </Section>
  );
}

export function SideBar(): JSX.Element {
  return (
    <>
      <SidebarTitle label='Weakest Precondition'>
        <Tools />
      </SidebarTitle>
      <Forms.SidebarForm className={Utils.classes('wp-sidebar')}>
        <ProversConfiguration />
      </Forms.SidebarForm>
    </>
  );
}
