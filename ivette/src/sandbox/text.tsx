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
import { TextView, TextProxy } from 'dome/text/richtext';
import { registerSandbox } from 'ivette';

/* -------------------------------------------------------------------------- */
/* --- Use Text                                                           --- */
/* -------------------------------------------------------------------------- */

function UseText(): JSX.Element {
  const [readOnly, setReadOnly] = React.useState(false);
  const [prefix, setPrefix] = React.useState('');
  const text = React.useMemo(() => new TextProxy(), []);
  const onLockUnlock = React.useCallback(() => setReadOnly((v) => !v), []);
  const updatePrefix = React.useCallback(
    () => setPrefix(text.toString().substring(0, 20).trim()),
    [text]
  );
  const push = React.useCallback(() => text.append(prefix), [text, prefix]);
  const onChange = Dome.useDebounced(updatePrefix, 200);
  return (
    <>
      <ToolBar>
        <Button icon={readOnly ? 'LOCK' : 'EDIT'} onClick={onLockUnlock} />
        <Filler />
        <Code>{`"${prefix}"`}</Code>
        <Button label="Push" enabled={prefix!==''} onClick={push} />
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
