/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2025                                                */
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
import { Button, ButtonGroup, Inset } from 'dome/frame/toolbars';
import { HelpIcon } from 'dome/help';
import * as Themes from 'dome/themes';
import { ledTag, iconTag, Pattern } from 'dome/text/markdown';
import docCallgraph from '../callgraph.md?raw';
import { ModeDisplay } from '../definitions';
import {
  IThreeStateButton, ThreeStateButton, TThreesButtonState
} from './threeStateButton';

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
      <HelpIcon
        label='Callgraph'
        scrollTo={'callgraph'}
        patterns={[iconTag, ledTag, selectButtonTag, TSButtonTag]}
      >{ docCallgraph }</HelpIcon>
      <Inset />
    </Ivette.TitleBar>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Callgraph documentation                                            --- */
/* -------------------------------------------------------------------------- */

/** Pattern used for callgraph documentation */
const TSButtonTag: Pattern = {
  pattern: /\[button-displaymode\]/g,
  replace: (key: number, match?: RegExpExecArray) => {
    return match ? <span key={key}>{DocShowNodesButton()}</span> : null;
  }
};

/** Pattern used for callgraph documentation */
const selectButtonTag: Pattern = {
  pattern: /\[button-select\]/g,
  replace: (key: number, match?: RegExpExecArray) => {
    return match ? <Button key={key} label="Select" title={`Nodes selection`}/>
      : null;
  }
};

interface ShowNodesButtonProps {
  displayModeState: [ModeDisplay, (newValue: ModeDisplay) => void],
  selectedParentsState: TThreesButtonState,
  selectedChildrenState: TThreesButtonState,
}

function ShowNodesButton(props: ShowNodesButtonProps): JSX.Element {
  const {
    displayModeState, selectedParentsState, selectedChildrenState
  } = props;
  const [ displayMode, setDisplayMode] = displayModeState;

  return (
    <ButtonGroup>
      <Button
        label='all'
        title='show all nodes'
        selected={displayMode === 'all'}
        onClick={() => setDisplayMode("all")}
        />
      <Button
        label='linked'
        title='only show nodes linked to the selected ones'
        selected={displayMode === 'linked'}
        onClick={() => setDisplayMode("linked")}
        />
      <Button
        label='selected'
        title='only show selected nodes, their parents and their childrens'
        selected={displayMode === 'selected'}
        onClick={() => setDisplayMode("selected")}
        />
      { displayMode === "selected" ? (
          <>
            <ThreeStateButton
              label={"Parents"}
              title={"Choose how many parents you want to see."}
              buttonState={selectedParentsState}
              />
            <ThreeStateButton
              label={"Children"}
              title={"Choose how many children you want to see."}
              buttonState={selectedChildrenState}
              />
          </>
        ) : <></>
      }
    </ButtonGroup>
  );
}

export function DocShowNodesButton(): JSX.Element {
  const displayModeState = React.useState<ModeDisplay>("all");
  const selectedParentsState = React.useState<IThreeStateButton>(
      { active: false, max: false, value: 1 });
  const selectedChildrenState = React.useState<IThreeStateButton>(
      { active: true, max: true, value: 1 });
  const [ displayMode, ] = displayModeState;
  const [ parent, ] = selectedParentsState;
  const [ children, ] = selectedChildrenState;

  const style = Themes.useStyle();
  const infosStyle = { color: style.getPropertyValue('--text-highlighted') };

  function getDocSelected(
    parent: IThreeStateButton,
    children: IThreeStateButton
  ):JSX.Element {
    function getDocTSB(name: string, tsb: IThreeStateButton):string {
      return !tsb.active ? '' :
        tsb.max ? ` all ${name}` :
          tsb.value > 0 ?
            (tsb.value+' level'+(tsb.value > 1 ? 's':'')+` of ${name}`):
            "";
    }
    const p = getDocTSB('parents', parent);
    const c = getDocTSB('children', children);

    return (
      <div style={infosStyle}>
        Selected nodes displayed { (p || c) && " with " }
        { p }{ p && c && " and " }{ c }
        { !p && !c && " only " }.
      </div>
    );
  }

  const docAll = <div style={infosStyle}>All nodes displayed.</div>;
  const docLinked = <div style={infosStyle}>Hide unlinked nodes.</div>;
  const docSelected = getDocSelected(parent, children);

  return (
    <>
      <ShowNodesButton
        displayModeState={displayModeState}
        selectedParentsState={selectedParentsState}
        selectedChildrenState={selectedChildrenState}
      />
      { displayMode === 'all' ? docAll :
        displayMode === 'linked' ? docLinked :
        docSelected
      }
    </>
  );
}
