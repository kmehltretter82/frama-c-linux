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
        title={`Functions filter`}
        onClick={() => Dome.popupMenu(contextMenuItems)}
      />
      <IconButton
        icon={"TARGET"}
        onClick={flipAutoCenter}
        kind={autoCenter ? "positive" : "default"}
        title={
          "If selected, the camera will be moved to show "+
          "each node after each render"}
      />
      <IconButton
        icon={"PIN"}
        onClick={flipAutoSelect}
        kind={autoSelect ? "positive" : "default"}
        title={"Selected nodes is sync with the current scope"}
      />
      <IconButton
        icon={"HELP"}
        title={"click: select element\n"+
          "ctrl+click: Multiselection\n"+
          "alt+click: change scope"}
        className="titlebar-thin-icon"
      />
    </Ivette.TitleBar>
  );
}
