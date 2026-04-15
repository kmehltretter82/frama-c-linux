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
  Field
} from 'dome/controls/buttons';
import { SidebarTitle } from 'dome/frame/sidebars';
import { DivProps, Hbox, Hfill, Vbox } from 'dome/layout/boxes';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';
import * as Params from 'frama-c/kernel/api/parameters';
import * as WP from 'frama-c/plugins/wp/api';
import * as TIP from './tip';

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
    <Forms.Section label='Provers Configuration' unfold>
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
    </Forms.Section>
  );
}

interface SelectionProps {
  name: string;
  selected: boolean;
  remove: () => void;
}

function SelectionButton(props: SelectionProps): JSX.Element {
  const { name, remove, selected } = props;
  const className = Utils.classes(
    'wp-sidebar-selection',
    (selected && 'wp-sidebar-selection-selected')
  );
  return (
    <div className={className}>
      <Label label={name} >
        <Icon
          id='CROSS'
          onClick={remove} />
      </Label>
    </div>
  );
}

function PropertiesFilter(): JSX.Element {
  const [properties = [], setProperties] = States.useSyncState(WP.filter);

  const [selected, setSelected] = React.useState<string>('');
  const onChange = (value: string | undefined): void => {
    setSelected(value ?? '');
  };

  const [field, setField] = React.useState<string>('');

  const custom = 'Custom:';

  const getName = (add: boolean): string => {
    const name = selected === custom ? field : selected;
    return add ? name : '-' + name;
  };
  const displayName = (name: string): string => {
    switch (name) {
      case '@disjoint_behaviors': return '@disjoint';
      case '@complete_behaviors': return '@complete';
      default: return name;
    }
  };

  const canCommit = (add: boolean): boolean => {
    if (selected === '') return false;
    if (selected === custom && field === '') return false;
    return properties.indexOf(getName(add)) === -1;
  };

  const remove = (ps: string[], value: string): string[] => {
    return ps.filter((element) => element !== value);
  };

  const onCommit = (add: boolean): void => {
    const toRm = getName(!add);
    const toAdd = getName(add);
    const updated =
      properties.indexOf(toRm) !== -1
        ? remove(properties, toRm)
        : [...properties, toAdd];
    setProperties(updated);
  };
  const onKill = (value: string): void => {
    setProperties(remove(properties, value));
  };

  const options = [
    '',
    '@assert',
    '@assigns',
    '@breaks',
    '@check',
    '@continues',
    '@complete_behaviors',
    '@decreases',
    '@disjoint_behaviors',
    '@ensures',
    '@exits',
    '@invariant',
    '@lemma',
    '@requires',
    '@returns',
    '@variant',
    '@terminates',
    custom
  ];

  return (
    <Forms.Section
      label='Properties filter'
    >
      <SidebarBlock>
        <div className={Utils.classes('wp-sidebar-selection-block')}>
          {properties.length !== 0 && <Button
            key='Reset'
            icon={'TRASH'}
            className={Utils.classes('wp-sidebar-selection')}
            onClick={() => setProperties([])}
          />}
          {properties.map((value) =>
            <SelectionButton
              key={value}
              name={value}
              selected={value === getName(true) || value === getName(false)}
              remove={() => onKill(value)} />)}
        </div>
        <Hbox>
          <Button
            icon={'PLUS'}
            enabled={canCommit(true)}
            onClick={() => { onCommit(true); }}
            className={Utils.classes('wp-sidebar-selection-commit')}
          />
          <Button
            icon={'MINUS'}
            enabled={canCommit(false)}
            onClick={() => { onCommit(false); }}
            className={Utils.classes('wp-sidebar-selection-commit')}
          />
          <SelectMenu
            value={selected}
            onChange={onChange}
          >
            {options.map((value) =>
              <option key={value} value={value}>{displayName(value)}</option>)}
          </SelectMenu>
          <Field
            style={selected !== custom ? { display: 'none' } : {}}
            onEdited={(value) => { setField(value); }}
          />
        </Hbox>
      </SidebarBlock>
    </Forms.Section>
  );
}

function Properties(): JSX.Element {
  const [rte = false, setRte] = States.useSyncState(Params.wpRte);
  const [smoke = false, setSmoke] = States.useSyncState(Params.wpSmokeTests);


  return (
    <Forms.Section label='Properties' unfold>
      <SidebarBlock title='Side conditions'>
        <Checkbox
          label='Generate RTE guards'
          onChange={setRte}
          value={rte}
        />
        <Checkbox
          label='Generate smoke tests'
          onChange={setSmoke}
          value={smoke}
        />
      </SidebarBlock>
      <PropertiesFilter />
    </Forms.Section>
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
        <Properties />
      </Forms.SidebarForm>
    </>
  );
}
