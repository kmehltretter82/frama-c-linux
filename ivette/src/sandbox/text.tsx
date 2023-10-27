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
import { Button } from 'dome/controls/buttons';
import { TextView, TextProxy, TextBuffer } from 'dome/text/richtext';
import { registerSandbox } from 'ivette';

/* -------------------------------------------------------------------------- */
/* --- Use Text                                                           --- */
/* -------------------------------------------------------------------------- */

function UseText(): JSX.Element {
  const [prefix, setPrefix] = React.useState('');
  const [readOnly, flipReadOnly] = Dome.useFlipState(false);
  const [useProxy, flipUseProxy] = Dome.useFlipState(true);
  const [changes, setChanges] = React.useState(0);
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
        <Filler />
        <Code>{`"${prefix}" (${changes})`}</Code>
        <Button label="Push" onClick={push} />
        <Button label="Clear" kind='negative' onClick={text.clear}  />
      </ToolBar>
      <TextView
        text={text}
        readOnly={readOnly}
        onChange={onChange}
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
