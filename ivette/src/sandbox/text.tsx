/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Testing of RichText                                        --- */
/* --- Only appears in DEVEL mode.                                        --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import * as Dome from 'dome';
import { ToolBar, Filler } from 'dome/frame/toolbars';
import { Code } from 'dome/controls/labels';
import { Button, IconButton } from 'dome/controls/buttons';
import {
  TextView,
  TextProxy,
  TextBuffer,
  empty,
  Decoration,
} from 'dome/text/richtext';
import { registerSandbox } from 'ivette';

/* -------------------------------------------------------------------------- */
/* --- Use Text                                                           --- */
/* -------------------------------------------------------------------------- */

function UseText(): JSX.Element {
  const [prefix, setPrefix] = React.useState('');
  const [readOnly, flipReadOnly] = Dome.useFlipState(false);
  const [useProxy, flipUseProxy] = Dome.useFlipState(false);
  const [changes, setChanges] = React.useState(0);
  const [s, onSelection] = React.useState(empty);
  const proxy = React.useMemo(() => new TextProxy(), []);
  const buffer = React.useMemo(() => new TextBuffer(), []);
  const text = useProxy ? proxy : buffer;
  const updatePrefix = React.useCallback(
    () => {
      setChanges((n) => 1+n);
      setPrefix(text.toString().substring(0, 20).trim());
    }, [text]);
  const push = React.useCallback(() => {
    const n = Math.random();
    text.append(`ADDED${n}\n`);
  }, [text]);
  const onChange = Dome.useDebounced(updatePrefix, 200);
  const [decorations, setDecorations] = React.useState<Decoration[]>([]);
  const clearDecorations = React.useCallback(() => setDecorations([]), []);

  const addDecoration = React.useCallback(() => {
    setDecorations([...decorations, {
      offset: s.offset,
      length: s.length,
      className: 'decoration',
      title: 'Decorated'
    }]);
  }, [decorations, s]);

  const addLineDecoration = React.useCallback(() => {
    setDecorations([...decorations, {
      line: s.fromLine,
      className: 'line-decoration',
      title: 'Line Decorated'
    }]);
  }, [decorations, s]);

  const addGutterDecoration = React.useCallback(() => {
    setDecorations([...decorations, {
      line: s.fromLine,
      gutter: '*',
    }]);
  }, [decorations, s]);

  return (
    <>
      <ToolBar>
        <Button
          icon={readOnly ? 'LOCK' : 'EDIT'}
          title={readOnly ? 'Read Only' : 'Editable'}
          onClick={flipReadOnly}
        />
        <Button
          icon={useProxy ? 'DISPLAY' : 'SAVE'}
          title={useProxy ? 'Use TextProxy' : 'Use TextBuffer (persistent)'}
          onClick={flipUseProxy}
        />
        <Code label={`Offset ${s.offset}-${s.offset + s.length}`} />
        <Code label={`Line ${s.fromLine}-${s.toLine}`} />
        <Code label={`Decorations ${decorations.length}`} />
        <IconButton
          display={s.length === 0}
          icon="CIRC.INFO"
          title="Add Gutter Decoration"
          onClick={addGutterDecoration}
        />
        <IconButton
          display={s.length === 0}
          icon="CIRC.CHECK"
          title="Add Line Decoration"
          onClick={addLineDecoration}
        />
        <IconButton
          display={s.length > 0}
          icon="CIRC.PLUS"
          title="Add Decoration"
          onClick={addDecoration}
        />
        <IconButton
          display={decorations.length > 0}
          icon="CIRC.CLOSE"
          title="Clear Decorations"
          onClick={clearDecorations} />
        <Filler />
        <Code>{`"${prefix}" (${changes})`}</Code>
        <Button label="Push" onClick={push} />
        <Button label="Clear" kind='negative' onClick={text.clear}  />
      </ToolBar>
      <TextView
        text={text}
        readOnly={readOnly}
        onChange={onChange}
        onSelection={onSelection}
        decorations={decorations}
      />
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.richtext',
  label: 'Rich Text',
  children: <UseText />,
});

/* -------------------------------------------------------------------------- */
