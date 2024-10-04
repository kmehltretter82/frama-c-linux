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

import * as Dome from 'dome';

import { State } from 'dome/data/states';
import {  Spinner } from 'dome/controls/buttons';
import { ToolBar, ButtonGroup, Button, Filler } from 'dome/frame/toolbars';

import {
  ModeDisplay, SelectedNodesData
} from "frama-c/plugins/callgraph/definitions";

import { IThreeStateButton, ThreeStateButton } from "./threeStateButton";

/* -------------------------------------------------------------------------- */
/* --- Callgraph Toolsbar component                                       --- */
/* -------------------------------------------------------------------------- */
interface CallgraphToolsBarProps {
  /* eslint-disable max-len */
  displayModeState: [ModeDisplay, (newValue: ModeDisplay) => void],
  selectedParentsState:
  [IThreeStateButton, (newValue: IThreeStateButton) => void],
  selectedChildrenState:
  [IThreeStateButton, (newValue: IThreeStateButton) => void],
  panelVisibleState: [boolean, () => void],
  verticalSpacingState: State<number>,
  horizontalSpacingState: State<number>,
  selectedFunctions:SelectedNodesData,
  taintedFunctions: string[],
  unprovenPropertiesFunctions: SelectedNodesData,
  cycleFunctions: string[],
  dagMode?: string;
  updateNodes: (newSet: SelectedNodesData) => void;
  /* eslint-enable max-len */
}

export function CallgraphToolsBar(props: CallgraphToolsBarProps): JSX.Element {
  const {
    displayModeState, selectedParentsState,
    selectedChildrenState, panelVisibleState,
    verticalSpacingState, horizontalSpacingState,
    selectedFunctions, taintedFunctions,
    unprovenPropertiesFunctions, cycleFunctions, dagMode,
    updateNodes
  } = props;

  const [displayMode, setDisplayMode] = displayModeState;
  const [showInfos, flipShowInfos] = panelVisibleState;
  const [verticalSpacing, setVerticalSpacing] = verticalSpacingState;
  const [horizontalSpacing, setHorizontalSpacing] = horizontalSpacingState;

  function menuItem(label: string, onClick: ()=>void, enabled?: boolean)
    : Dome.PopupMenuItem {
    return {
      label: label,
      enabled: enabled !== undefined ? enabled : true,
      onClick: onClick,
    };
  }

  const selectMenuItems: Dome.PopupMenuItem[] = [
    menuItem('Select functions with unproven properties',
      () => updateNodes(unprovenPropertiesFunctions),
      unprovenPropertiesFunctions.size !== 0),
    menuItem('Select functions listed in the Locations panel',
      () => updateNodes(selectedFunctions),
      selectedFunctions.size !== 0),
    menuItem('Select functions with tainted properties',
      () => updateNodes(new Set(taintedFunctions)),
      taintedFunctions.length !== 0),
    menuItem('Select cycles',
      () => updateNodes(new Set(cycleFunctions)),
      cycleFunctions.length !== 0),
  ];

  return (
    <ToolBar>
      <div className='cg-display-mode'>
        <ButtonGroup className='show-mode-button-group'>
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
      </div>

      <Button
        label="Select"
        title={`Nodes selection`}
        onClick={() => Dome.popupMenu(selectMenuItems)}
      />

      <Filler/>

      <div className='cg-spinner'>
        hor: <Spinner
        value={horizontalSpacing}
        title="Distance between the different graph depths"
        vmin={0}
        vstep={100}
        onChange={setHorizontalSpacing}
        />
      </div>
      <div className='cg-spinner'>
        ver: <Spinner
        disabled={dagMode === undefined}
        title={dagMode === undefined ?
          "Disabled if the graph has cycles":
          "Distance between the different graph depths"}
        value={verticalSpacing}
        vmin={0}
        vstep={20}
        onChange={setVerticalSpacing}
        />
      </div>
      <Button
        icon="SIDEBAR"
        title={showInfos ? "Hide panel" : "Show panel"}
        selected={showInfos}
        onClick={flipShowInfos}
      />
    </ToolBar>
  );
}
