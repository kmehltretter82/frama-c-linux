/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

// --------------------------------------------------------------------------
// --- AST Information
// --------------------------------------------------------------------------

import React from 'react';
import * as States from 'frama-c/states';
import * as Utils from 'frama-c/utils';

import { Vfill } from 'dome/layout/boxes';
import { RichTextBuffer } from 'dome/text/buffers';
import { Text } from 'dome/text/editors';
import { getInfo } from 'frama-c/api/kernel/ast';

// --------------------------------------------------------------------------
// --- Information Panel
// --------------------------------------------------------------------------

export default function ASTinfo() {

  const buffer = React.useMemo(() => new RichTextBuffer(), []);
  const [selection, updateSelection] = States.useSelection();
  const marker = selection?.current?.marker;
  const data = States.useRequest(getInfo, marker);

  React.useEffect(() => {
    buffer.clear();
    if (data) {
      Utils.printTextWithTags(buffer, data, { css: 'color: blue' });
    }
  }, [buffer, data]);

  // Callbacks
  function onTextSelection(id: string) {
    // For now, the only markers are functions.
    const location = { fct: id };
    updateSelection({ location });
  }

  // Component
  return (
    <>
      <Vfill>
        <Text
          buffer={buffer}
          mode="text"
          theme="default"
          onSelection={onTextSelection}
          readOnly
        />
      </Vfill>
    </>
  );
}

// --------------------------------------------------------------------------
