// --------------------------------------------------------------------------
// --- Server Controller
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';

import { Button as ToolButton, ButtonGroup, Space } from 'dome/frame/toolbars';
import { LED, IconButton } from 'dome/controls/buttons';
import { Label, Code } from 'dome/controls/labels';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';

import * as Server from 'frama-c/server';
import { Component, TitleBar } from 'frama-c/LabViews';

import 'codemirror/theme/ambiance.css';

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

let cmdConfig: Server.Configuration;
const cmdLine = new RichTextBuffer();

function dumpCmdLine(sc: Server.Configuration): void {
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

  let play = { enabled: false, onClick: () => { } };
  let stop = { enabled: false, onClick: () => { } };
  let reload = { enabled: false, onClick: () => { } };

  switch (status.stage) {
    case Server.Stage.OFF:
    case Server.Stage.FAILURE:
      play = { enabled: true, onClick: Server.start };
      break;
    case Server.Stage.ON:
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
  const [command, switchCmd] = Dome.useSwitch();
  const { current, next, prev, index, length, update, insert, clear }: any =
    Dome.useHistory('frama-c.command.history');

  const doExec = () => {
    const cmdline = getCmdLine();
    if (cmdline !== current) insert(cmdline);
    execCmdLine(cmdline);
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
      <TitleBar label={command ? 'Command Line' : 'Console'}>
        <Label className="dimmed" display={command && length > 0}>
          {1 + index}/{length}
        </Label>
        <Space />
        <IconButton
          icon="TRASH"
          display={command && clear}
          disabled={!clear}
          onClick={clear}
          title="Clear History"
        />
        <IconButton
          icon="CROSS"
          display={command && clear}
          disabled={!current}
          onClick={doDrop}
          title="Remove Command"
        />
        <Space />
        <IconButton
          icon="MEDIA.PREV"
          display={command}
          disabled={!prev}
          onClick={doPrev}
          title="Previous Command"
        />
        <IconButton
          icon="RELOAD"
          display={command}
          onClick={doReload}
          title="Reset Command Line"
        />
        <IconButton
          icon="MEDIA.NEXT"
          display={command}
          disabled={!next}
          onClick={doNext}
          title="Previous Command"
        />
        <Space />
        <IconButton
          icon="MEDIA.PLAY"
          display={command}
          onClick={doExec}
          title="Execute Command Line"
        />
        <IconButton
          icon="EDIT"
          selected={command}
          onClick={switchCmd}
          title="Edit Command Line"
        />
      </TitleBar>
      <Text
        buffer={command ? cmdLine : Server.buffer}
        mode="text"
        readOnly={!command}
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
  const status = Server.useStatus();
  const pending = Server.getPending();
  let led;
  let blink;
  let error;

  if (Server.hasErrorStatus(status)) {
    led = 'negative';
    blink = false;
    error = status.error;
  } else {
    switch (status.stage) {
      case Server.Stage.OFF:
        led = 'inactive';
        break;
      case Server.Stage.STARTING:
        led = 'active';
        blink = true;
        break;
      case Server.Stage.ON:
        led = pending > 0 ? 'positive' : 'active';
        break;
      case Server.Stage.HALTING:
        led = 'negative';
        blink = true;
        break;
      case Server.Stage.RESTARTING:
        led = 'warning';
        blink = true;
        break;
      default:
        break;
    }
  }

  return (
    <>
      <LED status={led} blink={blink} />
      <Code label={status.stage} />
      {error && <Label icon="WARNING" label={error} />}
    </>
  );
};

// --------------------------------------------------------------------------
// --- Server Stats
// --------------------------------------------------------------------------

export const Stats = () => {
  Server.useStatus();
  const pending = Server.getPending();
  return pending > 0 ? <Code>{pending} rq.</Code> : null;
};

// --------------------------------------------------------------------------
