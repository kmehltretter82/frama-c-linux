/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Server Controller
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import * as Settings from 'dome/data/settings';
import * as Preferences from 'ivette/prefs';
import * as Toolbars from 'dome/frame/toolbars';
import { IconButton } from 'dome/controls/buttons';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';
import * as Text from 'dome/text/richtext';
import { TextBuffer, TextView } from 'dome/text/richtext';
import { resolve } from 'dome/system';

import * as Ivette from 'ivette';
import * as Display from 'ivette/display';
import * as Server from 'frama-c/server';

// --------------------------------------------------------------------------
// --- Configure Server
// --------------------------------------------------------------------------

const quoteRe = new RegExp('^[-_./:a-zA-Z0-9]+$');
const quote = (s: string): string =>
  (quoteRe.test(s) ? s : `"${s}"`);

const unquoteRe = new RegExp('^".*"$');
const unquote = (s: string): string =>
  (unquoteRe.test(s) ? s.substring(1, s.length - 1) : s);

function dumpServerConfig(sc: Server.Configuration): string {
  let buffer = '';
  const { working, command, sockaddr, params } = sc;
  if (working) buffer += `--working ${quote(working)}\n`;
  if (command) buffer += `--command ${quote(command)}\n`;
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

function buildServerConfig(argv: string[], cwd?: string): Server.Configuration {
  const params = [];
  let command;
  let sockaddr;
  let working = cwd ? unquote(cwd) : undefined;
  for (let k = 0; k < (argv ? argv.length : 0); k++) {
    const v = argv[k];
    switch (v) {
      case '-C':
      case '--working':
      case '--cwd': // Deprecated
        k += 1;
        working = resolve(unquote(argv[k]));
        break;
      case '-B':
      case '--command':
        k += 1;
        command = resolve(unquote(argv[k]));
        break;
      case '-U':
      case '--socket':
        k += 1;
        sockaddr = argv[k];
        break;
      default:
        params.push(v);
    }
  }
  return {
    working,
    command,
    sockaddr,
    params,
  };
}

function buildServerCommand(cmd: string): Server.Configuration {
  return buildServerConfig(cmd.trim().split(/[ \t\n]+/));
}

/* -------------------------------------------------------------------------- */
/* --- History Management                                                 --- */
/* -------------------------------------------------------------------------- */

const historySetting = 'Controller.history';
const historyDecoder = Json.jList(Json.jString);

function getHistory(): string[] {
  return Settings.getLocalStorage(historySetting, historyDecoder, []);
}

function setHistory(hs: string[]): void {
  Settings.setLocalStorage(historySetting, hs);
}

function useHistory(): [string[], ((hs: string[]) => void)] {
  return Settings.useLocalStorage(historySetting, historyDecoder, []);
}

function insertConfig(hs: string[], cfg: Server.Configuration): string[] {
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

Dome.reload.on(() => {
  const [lastCmd] = getHistory();
  reloadCommand = lastCmd;
});

Dome.onCommand((argv: string[], cwd: string) => {
  let cfg;
  if (reloadCommand) {
    cfg = buildServerCommand(reloadCommand);
  } else {
    const hs = getHistory();
    if (argv.find((v) => v === '--reload' || v === '-R')) {
      cfg = buildServerCommand(hs[0]);
    } else {
      cfg = buildServerConfig(argv, cwd);
      setHistory(insertConfig(hs, cfg));
    }
  }
  Server.setConfig(cfg);
  Server.start();
});

// --------------------------------------------------------------------------
// --- Server Control
// --------------------------------------------------------------------------

export const Control = (): JSX.Element => {
  const status = Server.useStatus();

  let play = { enabled: false, onClick: () => { /* do nothing */ } };
  let stop = { enabled: false, onClick: () => { /* do nothing */ } };
  let reload = { enabled: false, onClick: () => { /* do nothing */ } };

  switch (status) {
    case Server.Status.OFF:
      play = { enabled: true, onClick: Server.start };
      break;
    case Server.Status.ON:
    case Server.Status.CMD:
    case Server.Status.FAILURE:
      stop = { enabled: true, onClick: Server.stop };
      reload = { enabled: true, onClick: Server.restart };
      break;
    default:
      break;
  }

  return (
    <Toolbars.ButtonGroup>
      <Toolbars.Button
        icon="MEDIA.PLAY"
        enabled={play.enabled}
        onClick={play.onClick}
        title="Start the server"
      />
      <Toolbars.Button
        icon="RELOAD"
        enabled={reload.enabled}
        onClick={reload.onClick}
        title="Restart the server"
      />
      <Toolbars.Button
        icon="MEDIA.STOP"
        enabled={stop.enabled}
        onClick={stop.onClick}
        title="Stop the server"
      />
    </Toolbars.ButtonGroup>
  );
};

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

const editor = new TextBuffer();

export function RenderConsole(): JSX.Element {
  const scratch = React.useRef([] as string[]);
  const [cursor, setCursor] = React.useState(-1);
  const [isEmpty, setEmpty] = React.useState(true);
  const [noTrash, setNoTrash] = React.useState(true);
  const [scrolling, setScrolling] = React.useState(true);
  const [history, setHistory] = useHistory();
  const [maxLines] = Settings.useGlobalSettings(Preferences.ConsoleScrollback);
  const edited = 0 <= cursor;
  const headCmd = history[0];

  const onVisible = React.useCallback((s: Text.Selection) => {
    if (!edited) {
      const { offset, length } = Server.buffer.range();
      const endOfBuffer = offset + length;
      const endOfViewport = s.offset + s.length;
      setScrolling(endOfViewport >= endOfBuffer);
    }
  }, [edited, setScrolling]);

  const flipScrolling = React.useCallback(() => setScrolling((s) => !s), []);

  const onChanged = React.useCallback(() => {
    if (edited) {
      const cmd = editor.toString().trim();
      setEmpty(cmd === '');
      setNoTrash((noTrash) => noTrash && cmd === headCmd);
    } else {
      const { length, toLine: lines } = Server.buffer.range();
      if (lines > maxLines) {
        const cut = Server.buffer.lineRange(lines - maxLines + 1);
        Server.buffer.replaceContents({ offset: 0, length: cut.offset });
        if (scrolling)
          Server.buffer.scrollTo({ offset: length - cut.offset, length: 0 });
      } else {
        if (scrolling)
          Server.buffer.scrollTo({ offset: length, length: 0 });
      }
    }
  }, [scrolling, edited, maxLines, headCmd]);

  const doReload = (): void => {
    const cfg = Server.getConfig();
    const hst = insertConfig(history, cfg);
    const cmd = hst[0];
    scratch.current = hst.slice();
    editor.setContents(cmd);
    setEmpty(cmd === '');
    setHistory(hst);
    setCursor(0);
  };

  const doSwitch = (): void => {
    if (edited) {
      editor.clear();
      scratch.current = [];
      setCursor(-1);
    } else {
      doReload();
    }
  };

  const doExec = (): void => {
    const cfg = buildServerCommand(editor.toString());
    const hst = insertConfig(history, cfg);
    setHistory(hst);
    setCursor(-1);
    editor.clear();
    setScrolling(true);
    Server.setConfig(cfg);
    Server.restart();
  };

  const doMove = (target: number): (undefined | (() => void)) => {
    if (0 <= target && target < history.length && target !== cursor)
      return (): void => {
        const cmd = editor.toString();
        const pad = scratch.current;
        pad[cursor] = cmd;
        const cmd2 = pad[target];
        editor.setContents(cmd2);
        setEmpty(cmd2 === '');
        setCursor(target);
      };
    return undefined;
  };

  const doRemove = (): void => {
    const n = history.length;
    if (n <= 1) doReload();
    else {
      const hst = history.slice();
      const pad = scratch.current;
      hst.splice(cursor, 1);
      pad.splice(cursor, 1);
      setHistory(hst);
      const next = cursor > 0 ? cursor - 1 : 0;
      editor.setContents(pad[next]);
      setCursor(next);
    }
  };

  const doPrev = doMove(cursor + 1);
  const doNext = doMove(cursor - 1);
  const n = history.length;

  return (
    <>
      <Ivette.TitleBar label={edited ? 'Command line' : 'Console'}>
        <IconButton
          icon="TRASH"
          display={edited}
          disabled={noTrash}
          onClick={doRemove}
          title="Remove command from history (irreversible)"
        />
        <Toolbars.Space />
        <IconButton
          icon="RELOAD"
          display={edited}
          onClick={doReload}
          title="Discard command edits"
        />
        <IconButton
          icon="ANGLE.LEFT"
          display={edited}
          onClick={doPrev}
          title="Show previous command"
        />
        <IconButton
          icon="ANGLE.RIGHT"
          display={edited}
          onClick={doNext}
          title="Show next command"
        />
        <Toolbars.Space />
        <Label
          className="component-info"
          title="Command history (newest first)"
          display={edited}
        >
          {1 + cursor} / {n}
        </Label>
        <Toolbars.Space />
        <IconButton
          icon="MEDIA.PLAY"
          display={edited}
          disabled={isEmpty}
          onClick={doExec}
          title="Run command"
        />
        <IconButton
          icon="TERMINAL"
          selected={edited}
          onClick={doSwitch}
          title="Toggle command-line editing"
        />
        <IconButton
          icon="MEDIA.NEXT"
          disabled={edited}
          selected={scrolling}
          onClick={flipScrolling}
          title="Auto-scroll console"
        />
      </Ivette.TitleBar>
      <TextView
        text={edited ? editor : Server.buffer}
        readOnly={!edited}
        onChange={onChanged}
        onViewport={onVisible}
        onSelection={onVisible}
        showCurrentLine={!scrolling}
        scrollToBottom={true}
      />
    </>
  );
}

// --------------------------------------------------------------------------
// --- Status
// --------------------------------------------------------------------------

Server.onStatus((s: Server.Status) => {
  switch (s) {
    case Server.Status.OFF:
    case Server.Status.STARTING:
    case Server.Status.RESTARTING:
      Display.clearMessages();
      return;
    case Server.Status.FAILURE:
      Display.showError('Frama-C Server Failure');
      Display.alertComponent('fc.kernel.console');
      return;
  }
});

export const Status = (): JSX.Element => {
  const status = Server.useStatus();
  const pending = Server.getPending();
  let icon = 'CIRC.EMPTY';
  let title = undefined;
  let spinning = false;

  switch (status) {
    case Server.Status.OFF:
      title = 'Server is off';
      break;
    case Server.Status.STARTING:
      icon = 'SPINNER';
      spinning = true;
      title = 'Server is starting';
      break;
    case Server.Status.ON:
      icon = pending > 0 ? 'SPINNER' : 'CIRC.CHECK';
      spinning = pending > 0;
      title = pending > 0
        ? `Server is running (${pending} pending requests)`
        : 'Server is running (idle)';
      break;
    case Server.Status.CMD:
      icon = 'TERMINAL';
      title = 'Processing command-line arguments';
      break;
    case Server.Status.HALTING:
      icon = 'MEDIA.STOP';
      title = 'Server is stopping';
      break;
    case Server.Status.RESTARTING:
      icon = 'RELOAD';
      spinning = true;
      title = 'Server is restarting';
      break;
    case Server.Status.FAILURE:
      icon = 'CIRC.CLOSE';
      title = 'Server stopped due to a failure';
      break;
  }

  return (
    <Icon
      id={icon}
      size={14}
      offset={0}
      spinning={spinning}
      className="server-status"
      title={title}
    />
  );
};

// --------------------------------------------------------------------------
