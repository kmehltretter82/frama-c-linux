// --------------------------------------------------------------------------
// --- Server Controller
// --------------------------------------------------------------------------

import React from 'react';
import Dome from 'dome';

import { Button as ToolButton, ButtonGroup, Space } from 'dome/layout/toolbars';
import { LED, IconButton } from 'dome/controls/buttons';
import { Label, Code } from 'dome/controls/labels';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';

import Server, { StatusCode, ServerConfiguration } from 'frama-c/server';
import { Component, TitleBar } from 'frama-c/LabViews';

import 'codemirror/theme/ambiance.css';

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

let cmdConfig: ServerConfiguration;
const cmdLine = new RichTextBuffer();

function dumpCmdLine(sc: ServerConfiguration): void {
  const { cwd, command, sockaddr, params } = sc;
  cmdLine.clear();
  if (cwd) cmdLine.log('--cwd', cwd);
  if (command) cmdLine.log('--command', command);
  if (sockaddr) cmdLine.log('--socket', sockaddr);
  if (params) {
    params.forEach((v: string, i: number) => {
      if (i > 0) {
        if (v.startsWith('-') || v.endsWith('.c')
          || v.endsWith('.h') || v.endsWith('.i')) {
          cmdLine.append('\n');
        } else {
          cmdLine.append(' ');
        }
      }
      cmdLine.append(v);
    });
  }
  cmdLine.append('\n');
}

function buildServerConfiguration(argv: string[], cwd?: string) {
  const params = [];
  let command;
  let sockaddr;
  let cwdir = cwd;
  for (let k = 0; k < argv.length; k++) {
    const v = argv[k];
    switch (v) {
      case '--cwd':
        k += 1;
        cwdir = argv[k];
        break;
      case '--command':
        k += 1;
        command = argv[k];
        break;
      case '--socket':
        k += 1;
        sockaddr = argv[k];
        break;
      default:
        params.push(v);
    }
  }
  return {
    cwd: cwdir,
    command,
    sockaddr,
    params,
  };
}

Dome.onCommand((argv: string[], cwd: string) => {
  cmdConfig = buildServerConfiguration(argv, cwd);
  dumpCmdLine(cmdConfig);
  Server.configure(cmdConfig);
  Server.start();
});

// --------------------------------------------------------------------------
// --- Server Control
// --------------------------------------------------------------------------

export const Control = () => {
  const status = Server.useStatus();

  let play: { enabled: boolean; onClick: any } =
    { enabled: false, onClick: null };
  let stop: { enabled: boolean; onClick: any } =
    { enabled: false, onClick: null };
  let reload: { enabled: boolean; onClick: any } =
    { enabled: false, onClick: null };

  switch (status) {
    case StatusCode.OFF:
    case StatusCode.FAILED:
      play = { enabled: true, onClick: Server.start };
      break;
    case StatusCode.RUNNING:
      stop = { enabled: true, onClick: Server.stop };
      reload = { enabled: true, onClick: Server.restart };
      break;
    default:
      break;
  }
  return (
    <ButtonGroup>
      <ToolButton
        icon="MEDIA.PLAY"
        enabled={play.enabled}
        onClick={play.onClick}
        title="Start the server"
      />
      <ToolButton
        icon="RELOAD"
        enabled={reload.enabled}
        onClick={reload.onClick}
        title="Re-start the server"
      />
      <ToolButton
        icon="MEDIA.STOP"
        enabled={stop.enabled}
        onClick={stop.onClick}
        title="Shut down the server"
      />
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
  const argv = cmd.split(/[ \t\n]+/);
  const cfg = buildServerConfiguration(argv);
  Server.configure(cfg);
  Server.restart();
}

const RenderConsole = () => {
  const [cmd, switchCmd] = Dome.useSwitch();
  const { current, next, prev, index, length, update, insert, clear }: any =
    Dome.useHistory('frama-c.command.history');

  const doExec = () => {
    const cmd = getCmdLine();
    if (cmd !== current) insert(cmd);
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
    <>
      <TitleBar label={cmd ? 'Command Line' : 'Console'}>
        <Label className="dimmed" display={cmd && length > 0}>
          {1 + index}/{length}
        </Label>
        <Space />
        <IconButton
          icon="TRASH"
          display={cmd && clear}
          disabled={!clear}
          onClick={clear}
          title="Clear History"
        />
        <IconButton
          icon="CROSS"
          display={cmd && clear}
          disabled={!current}
          onClick={doDrop}
          title="Remove Command"
        />
        <Space />
        <IconButton
          icon="MEDIA.PREV"
          display={cmd}
          disabled={!prev}
          onClick={doPrev}
          title="Previous Command"
        />
        <IconButton
          icon="RELOAD"
          display={cmd}
          onClick={doReload}
          title="Reset Command Line"
        />
        <IconButton
          icon="MEDIA.NEXT"
          display={cmd}
          disabled={!next}
          onClick={doNext}
          title="Previous Command"
        />
        <Space />
        <IconButton
          icon="MEDIA.PLAY"
          display={cmd}
          onClick={doExec}
          title="Execute Command Line"
        />
        <IconButton
          icon="EDIT"
          selected={cmd}
          onClick={switchCmd}
          title="Edit Command Line"
        />
      </TitleBar>
      <Text
        buffer={cmd ? cmdLine : Server.buffer}
        mode="text"
        readOnly={!cmd}
        theme="ambiance"
      />
    </>
  );
};

export const Console = () => (
  <Component
    id="frama-c.console"
    label="Console"
    title="Frama-C Server Output & Command Line"
  >
    <RenderConsole />
  </Component>
);

// --------------------------------------------------------------------------
// --- Status
// --------------------------------------------------------------------------

export const Status = () => {
  Dome.useUpdate(Server.STATUS);
  const s = Server.getStatus();
  const n = Server.getPending();
  let led;
  let blink;
  let error;
  switch (s) {
    case StatusCode.OFF:
      led = 'inactive';
      break;
    case StatusCode.STARTED:
      led = 'active';
      blink = true;
      break;
    case StatusCode.RUNNING:
      led = n > 0 ? 'positive' : 'active';
      break;
    case StatusCode.KILLING:
      led = 'negative';
      blink = true;
      break;
    case StatusCode.RESTART:
      led = 'warning';
      blink = true;
      break;
    case StatusCode.FAILED:
      led = 'negative';
      blink = false;
      error = Server.getError();
      break;
    default:
      break;
  }
  return (
    <>
      <LED status={led} blink={blink} />
      <Code label={s} />
      {error && <Label icon="WARNING" label={error} />}
    </>
  );
};

// --------------------------------------------------------------------------
// --- Server Stats
// --------------------------------------------------------------------------

export const Stats = () => {
  Dome.useUpdate(Server.STATUS);
  const n = Server.getPending();
  return n > 0 ? <Code>{n} rq.</Code> : null;
};

// --------------------------------------------------------------------------
// --- Controller Exports
// --------------------------------------------------------------------------

export default {
  Control,
  Console,
  Status,
  Stats,
};

// --------------------------------------------------------------------------
