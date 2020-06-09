// --------------------------------------------------------------------------
// --- Server Controller
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';

import { Button as ToolButton, ButtonGroup, Space } from 'dome/frame/toolbars';
import { LED, LEDstatus, IconButton } from 'dome/controls/buttons';
import { Label, Code } from 'dome/controls/labels';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';

import * as Server from 'frama-c/server';
import { Component, TitleBar } from 'frama-c/LabViews';

import 'codemirror/theme/ambiance.css';

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

const quoteRe = new RegExp('^[-./:a-zA-Z0-9]+$');
const quote = (s: string) => (quoteRe.test(s) ? s : `"${s}"`);

function dumpServerConfig(sc: Server.Configuration): string {
  let buffer = '';
  const { cwd, command, sockaddr, params } = sc;
  if (cwd) buffer += `--cwd ${quote(cwd)}\n`;
  if (command) buffer += `--command ${command}\n`;
  if (sockaddr) buffer += `--socket ${sockaddr}\n`;
  if (params) {
    params.forEach((v: string, i: number) => {
      if (i > 0) {
        if (v.startsWith('-') || v.endsWith('.c')
          || v.endsWith('.h') || v.endsWith('.i')) {
          buffer += '\n';
        } else
          buffer += ' ';
      }
      buffer += v;
    });
  }
  return buffer;
}

function buildServerConfig(argv: string[], cwd?: string) {
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

function buildServerCommand(cmd: string) {
  return buildServerConfig(cmd.trim().split(/[ \t\n]+/));
}

function insertConfig(hs: string[], cfg: Server.Configuration) {
  const cmd = dumpServerConfig(cfg).trim();
  const newhs =
    hs.map((h) => h.trim())
      .filter((h: string) => h !== cmd && h !== '')
      .slice(0, 50);
  newhs.unshift(cmd);
  return newhs;
}

// --------------------------------------------------------------------------
// --- Start Server on Command
// --------------------------------------------------------------------------

let reloadCommand: string | undefined;

Dome.onReload(() => {
  const hst = Dome.getWindowSetting('Controller.history');
  reloadCommand = Array.isArray(hst) && hst[0];
});

Dome.onCommand((argv: string[], cwd: string) => {
  let cfg;
  if (reloadCommand) {
    cfg = buildServerCommand(reloadCommand);
  } else {
    cfg = buildServerConfig(argv, cwd);
  }
  Server.setConfig(cfg);
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

const editor = new RichTextBuffer();

const RenderConsole = () => {
  const scratch = React.useRef([] as string[]);
  const [cursor, setCursor] = React.useState(-1);
  const [H0, setH0] = Dome.useState('Controller.history', []);
  const [isEmpty, setEmpty] = React.useState(true);
  const [noTrash, setNoTrash] = React.useState(true);

  // Cope with merge settings that keeps previous array entries (BUG in DOME)
  const history = Array.isArray(H0) ? H0.filter((h) => h !== '') : [];
  const setHistory = (hs: string[]) => {
    const n = hs.length;
    setH0(n < 50 ? hs.concat(Array(50 - n).fill('')) : hs);
  };

  Dome.useEmitter(editor, 'change', () => {
    const cmd = editor.getValue().trim();
    setEmpty(cmd === '');
    setNoTrash(cursor === 0 && history.length === 1 && cmd === history[0]);
  });

  const doReload = () => {
    const cfg = Server.getConfig();
    const hst = insertConfig(history, cfg);
    scratch.current = hst.slice();
    editor.setValue(hst[0]);
    setHistory(hst);
    setCursor(0);
  };

  const doSwitch = () => {
    if (cursor < 0) doReload();
    else {
      editor.clear();
      scratch.current = [];
      setCursor(-1);
    }
  };

  const doExec = () => {
    const cfg = buildServerCommand(editor.getValue());
    const hst = insertConfig(history, cfg);
    setHistory(hst);
    setCursor(-1);
    editor.clear();
    Server.setConfig(cfg);
    Server.restart();
  };

  const doMove = (target: number) => {
    if (0 <= target && target < history.length && target !== cursor)
      return () => {
        const cmd = editor.getValue();
        const pad = scratch.current;
        pad[cursor] = cmd;
        editor.setValue(pad[target]);
        setCursor(target);
      };
    return undefined;
  };

  const doRemove = () => {
    const n = history.length;
    if (n <= 1) doReload();
    else {
      const hst = history.slice();
      const pad = scratch.current;
      hst.splice(cursor, 1);
      pad.splice(cursor, 1);
      setHistory(hst);
      const next = cursor > 0 ? cursor - 1 : 0;
      editor.setValue(pad[next]);
      setCursor(next);
    }
  };

  const doPrev = doMove(cursor + 1);
  const doNext = doMove(cursor - 1);
  const edited = 0 <= cursor;
  const n = history.length;

  return (
    <>
      <TitleBar label={edited ? 'Command line' : 'Console'}>
        <IconButton
          icon="TRASH"
          display={edited}
          disabled={noTrash}
          onClick={doRemove}
          title="Discard command from history (irreversible)"
        />
        <Space />
        <IconButton
          icon="RELOAD"
          display={edited}
          onClick={doReload}
          title="Discard changes"
        />
        <IconButton
          icon="MEDIA.PREV"
          display={edited}
          onClick={doPrev}
          title="Previous command"
        />
        <IconButton
          icon="MEDIA.NEXT"
          display={edited}
          onClick={doNext}
          title="Next command"
        />
        <Space />
        <Label
          className="component-info"
          title="History (last command first)"
          display={edited}
        >
          {1 + cursor} / {n}
        </Label>
        <Space />
        <IconButton
          icon="MEDIA.PLAY"
          display={edited}
          disabled={isEmpty}
          onClick={doExec}
          title="Execute command"
        />
        <IconButton
          icon="TERMINAL"
          selected={edited}
          onClick={doSwitch}
          title="Toggle command line editing"
        />
      </TitleBar>
      <Text
        buffer={edited ? editor : Server.buffer}
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
  let led: LEDstatus;
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
