// --------------------------------------------------------------------------
// --- Server Controller
// --------------------------------------------------------------------------

import React from 'react';
import Dome from 'dome';
import Server from 'frama-c/server';

import { Component, TitleBar } from 'frama-c/LabViews';
import { Button as ToolButton, ButtonGroup, Space } from 'dome/layout/toolbars';
import { LED, IconButton } from 'dome/controls/buttons';
import { Label, Code } from 'dome/controls/labels';
import { Buffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';

import 'codemirror/theme/ambiance.css';
import { STATUS_CODE } from 'frama-c/server';

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

var cmdConfig: any;
const cmdLine = new Buffer();

function dumpCmdLine(config: any = {}) {
  const { cwd, command, sockaddr, params } = config;
  cmdLine.clear();
  if (cwd) cmdLine.log('--cwd', cwd);
  if (command) cmdLine.log('--command', command);
  if (sockaddr) cmdLine.log('--socket', sockaddr);
  if (params) params.forEach((v: string, i: number) => {
    if (i > 0) {
      if (v.startsWith('-') || v.endsWith('.c') || v.endsWith('.h') || v.endsWith('.i'))
        cmdLine.append('\n');
      else
        cmdLine.append(' ');
    }
    cmdLine.append(v);
  });
  cmdLine.append('\n');
};

function configOfParams(argv: string[], cwd: string | null) {
  let params = [];
  let command;
  let sockaddr;
  let working = cwd;
  for (let k = 0; k < argv.length; k++) {
    let v = argv[k];
    switch (v) {
      case '--cwd':
        working = argv[++k];
        break;
      case '--command':
        command = argv[++k];
        break;
      case '--socket':
        sockaddr = argv[++k];
        break;
      default:
        params.push(v);
    }
  }
  return { cwd: working, command, sockaddr, params };
}

Dome.onCommand((argv: string[], cwd: string) => {
  cmdConfig = configOfParams(argv, cwd);
  dumpCmdLine(cmdConfig);
  Server.configure(cmdConfig);
  Server.start();
});

// --------------------------------------------------------------------------
// --- Server Control
// --------------------------------------------------------------------------

export const Control = () => {
  let status: STATUS_CODE = Server.useStatus();
  let play: { enabled: boolean, onClick: any } = { enabled: false, onClick: null };
  let stop: { enabled: boolean, onClick: any } = { enabled: false, onClick: null };
  let reload: { enabled: boolean, onClick: any } = { enabled: false, onClick: null };
  switch (status) {
    case STATUS_CODE.OFF:
    case STATUS_CODE.FAILED:
      play = { enabled: true, onClick: Server.start };
      break;
    case STATUS_CODE.RUNNING:
      stop = { enabled: true, onClick: Server.stop };
      reload = { enabled: true, onClick: Server.restart };
      break;
  }
  return (
    <ButtonGroup>
      <ToolButton icon='MEDIA.PLAY' {...play}
        title='Start the server' />
      <ToolButton icon='RELOAD' {...reload}
        title='Re-start the server' />
      <ToolButton icon='MEDIA.STOP' {...stop}
        title='Shut down the server' />
    </ButtonGroup>
  );
};

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

function getCmdLine() {
  return cmdLine.getDoc().getValue().trim();
}

function execCmdLine(cmd: string) {
  let argv = cmd.split(/[ \t\n]+/);
  let cfg: any = configOfParams(argv, null);
  Server.configure(cfg);
  Server.restart();
}

const RenderConsole = () => {
  const [cmd, switchCmd] = Dome.useSwitch();
  const { current, next, prev, index, length, update, insert, clear }: any = Dome.useHistory('frama-c.command.history');
  const doExec = () => {
    let cmd = getCmdLine();
    if (cmd != current) insert(cmd);
    execCmdLine(cmd);
    switchCmd();
  };
  const doNext = () => { cmdLine.getDoc().setValue(next() || ''); };
  const doPrev = () => { cmdLine.getDoc().setValue(prev() || ''); };
  const doReload = () => { dumpCmdLine(cmdConfig); };
  const doDrop = () => {
    cmdLine.clear();
    cmdLine.getDoc().setValue(update(undefined) || '');
  };
  return (
    <React.Fragment>
      <TitleBar label={cmd ? 'Command Line' : 'Console'}>
        <Label className='dimmed' display={cmd && length > 0}>
          {1 + index}/{length}
        </Label>
        <Space />
        <IconButton icon='TRASH' display={cmd && clear} disabled={!clear} onClick={clear} title='Clear History' />
        <IconButton icon='CROSS' display={cmd && clear} disabled={!current} onClick={doDrop} title='Remove Command' />
        <Space />
        <IconButton icon='MEDIA.PREV' display={cmd} disabled={!prev} onClick={doPrev} title='Previous Command' />
        <IconButton icon='RELOAD' display={cmd} onClick={doReload} title='Reset Command Line' />
        <IconButton icon='MEDIA.NEXT' display={cmd} disabled={!next} onClick={doNext} title='Previous Command' />
        <Space />
        <IconButton icon='MEDIA.PLAY' display={cmd} onClick={doExec} title='Execute Command Line' />
        <IconButton icon='EDIT' selected={cmd} onClick={switchCmd} title='Edit Command Line' />
      </TitleBar>
      <Text buffer={cmd ? cmdLine : Server.buffer}
        mode='text'
        readOnly={!cmd}
        theme='ambiance' />
    </React.Fragment>
  );
};

export const Console = () => (
  <Component id='frama-c.console'
    label='Console'
    title='Frama-C Server Output & Command Line'>
    <RenderConsole />
  </Component>
);

// --------------------------------------------------------------------------
// --- Status
// --------------------------------------------------------------------------

export const Status = () => {
  Dome.useUpdate(Server.STATUS);
  let s = Server.getStatus();
  let n = Server.getPending();
  let led, blink, error;
  switch (s) {
    case STATUS_CODE.OFF:
      led = 'inactive';
      break;
    case STATUS_CODE.STARTED:
      led = 'active';
      blink = true;
      break;
    case STATUS_CODE.RUNNING:
      led = n > 0 ? 'positive' : 'active';
      break;
    case STATUS_CODE.KILLING:
      led = 'negative';
      blink = true;
      break;
    case STATUS_CODE.RESTART:
      led = 'warning';
      blink = true;
      break;
    case STATUS_CODE.FAILED:
      led = 'negative';
      blink = false;
      error = Server.getError();
      break;
  }
  return (
    <React.Fragment>
      <LED status={led} blink={blink} />
      <Code label={s} />
      {error && <Label icon='WARNING' label={error} />}
    </React.Fragment>
  );
};

// --------------------------------------------------------------------------
// --- Server Stats
// --------------------------------------------------------------------------

export const Stats = () => {
  Dome.useUpdate(Server.STATUS);
  let n = Server.getPending();
  return n > 0 ? <Code>{n} rq.</Code> : null;
};

// --------------------------------------------------------------------------
// --- Controller Exports
// --------------------------------------------------------------------------

export default { Control, Console, Status, Stats };

// --------------------------------------------------------------------------
