/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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

import React from 'react';

import * as Ivette from 'ivette';
import * as Dome from 'dome';

import { IconButton } from 'dome/controls/buttons';
import { Inset } from 'dome/frame/toolbars';
import * as Dialogs from 'dome/dialogs';

// Help popup
async function displayShortcuts(): Promise<void> {
  await Dialogs.showMessageBox({
    buttons: [{ label: "Ok" }],
    details: (
      'In the graph:\n' +
      '  - Left-click: rotate the graph\n' +
      '  - Right-click: move in the graph\n' +
      '  - Mouse-wheel: zoom\n' +
      '\n' +
      'On nodes:\n' +
      '  - Left-Click: select node (in the graph)\n'+
      '  - Ctrl+click: add node to the selected nodes (multi-selection)\n' +
      '  - Alt+click: select function (in all Ivette components)\n' +
      '\n' +
      'Function filters (in the titlebar of this component) are synchronized ' +
      'with the filter of the functions sidebar.'
    ),
    message: 'Callgraph Help',
  });
}

/* -------------------------------------------------------------------------- */
/* --- Callgraph titlebar component                                       --- */
/* -------------------------------------------------------------------------- */
interface CallgraphTitleBarProps {
  /** Context menu to filtering nodes */
  contextMenuItems: Dome.PopupMenuItem[],
  /** automatic graph centering */
  autoCenterState: [boolean, () => void],
  /** automatic selection */
  autoSelectState: [boolean, () => void]
}

export function CallgraphTitleBar(props: CallgraphTitleBarProps): JSX.Element {
  const { autoCenterState, autoSelectState, contextMenuItems } = props;
  const [ autoCenter, flipAutoCenter ] = autoCenterState;
  const [ autoSelect, flipAutoSelect] = autoSelectState;

  return (
    <Ivette.TitleBar>
      <IconButton
        icon={'TUNINGS'}
        title={`Filter functions appearing in the graph`}
        onClick={() => Dome.popupMenu(contextMenuItems)}
      />
      <Inset />
      <IconButton
        icon={"TARGET"}
        onClick={flipAutoCenter}
        kind={autoCenter ? "positive" : "default"}
        title={"Move the camera to show each node after each render"}
      />
      <IconButton
        icon={"PIN"}
        onClick={flipAutoSelect}
        kind={autoSelect ? "positive" : "default"}
        title={"Automatically select node of the function selected in AST"}
      />
      <Inset />
      <IconButton
        icon="HELP"
        onClick={displayShortcuts}
        title='Callgraph help'
      />
      <Inset />
    </Ivette.TitleBar>
  );
}
