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

const RenderConsole = () => {
  const scratch = React.useRef([] as string[]);
  const [cursor, setCursor] = React.useState(-1);
  const [h0, setHistory] = Dome.useState('Controller.history', []);
  const history = Array.isArray(h0) ? h0 : [];

  const doExec = () => {
    const cmd = cmdLine.getDoc().getValue().trim();
    cmdLine.clear();
    const argv = cmd.split(/[ \t\n]+/);
    const cfg = buildServerConfiguration(argv);
    Server.configure(cfg);
    Server.restart();
    setCursor(-1);
  };

  const doEdit = () => {
    if (cursor < 0) {
      dumpCmdLine(Server.getConfig());
      const cmd = cmdLine.getDoc().getValue().trim();
      const hs = history
        .filter((h: string) => h !== cmd && h !== '')
        .slice(0, 50);
      hs.unshift(cmd);
      scratch.current = hs.slice();
      setHistory(hs);
      setCursor(0);
    } else {
      cmdLine.clear();
      scratch.current = [];
      setCursor(-1);
    }
  };

  const doMove = (target: number) => {
    if (0 <= target && target < history.length)
      return () => {
        const doc = cmdLine.getDoc();
        const cmd = scratch.current;
        cmd[cursor] = doc.getValue();
        doc.setValue(cmd[target]);
        setCursor(target);
      };
    return undefined;
  };

  const doReload = () => {
    const doc = cmdLine.getDoc();
    const cmd = scratch.current;
    if (cursor !== 0) cmd[cursor] = doc.getValue();
    dumpCmdLine(Server.getConfig());
    cmd[0] = doc.getValue();
    setCursor(0);
  };

  const doRemove = () => {
    const n = history.length;
    if (n > 1) {
      const hst = history.slice();
      const cmd = scratch.current;
      const next = cursor - 1;
      hst.splice(cursor, 1);
      cmd.splice(cursor, 1);
      cmdLine.getDoc().setValue(scratch.current[next]);
      setHistory(hst);
      setCursor(next);
    } else {
      scratch.current = [''];
      cmdLine.getDoc().setValue('');
    }
  };

  const doPrev = doMove(cursor + 1);
  const doNext = doMove(cursor - 1);
  const edited = 0 <= cursor;
  const n = history.length;

  return (
    <>
      <TitleBar label={edited ? 'Command Line' : 'Console'}>
        <IconButton
          icon="TRASH"
          display={edited}
          onClick={doRemove}
          title="Discard Command from History"
        />
        <Space />
        <IconButton
          icon="RELOAD"
          display={edited}
          onClick={doReload}
          title="Reset Server Command"
        />
        <IconButton
          icon="MEDIA.PREV"
          display={edited}
          onClick={doPrev}
          title="Previous Command"
        />
        <Label
          className="dimmed"
          display={edited && n > 0}
          title="Rank in History"
        >
          {1 + cursor}/{n}
        </Label>
        <IconButton
          icon="MEDIA.NEXT"
          display={edited}
          onClick={doNext}
          title="Next Command"
        />
        <Space />
        <IconButton
          icon="MEDIA.PLAY"
          display={edited}
          onClick={doExec}
          title="Execute Command"
        />
        <IconButton
          icon="TERMINAL"
          selected={edited}
          onClick={doEdit}
          title="Edit Command"
        />
      </TitleBar>
      <Text
        buffer={edited ? cmdLine : Server.buffer}
        mode="text"
        readOnly={!edited}
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
