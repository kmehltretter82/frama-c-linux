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

import { Item, SideBar, SidebarTitle } from 'dome/frame/sidebars';
import { LED } from 'dome/controls/displays';
import * as Forms from 'dome/layout/forms';
import { Dropdown } from 'dome/dialogs';
import { Button } from 'dome/frame/toolbars';

import * as Params from 'frama-c/kernel/api/parameters';

import { IsSetElement, OptionsHelp, SelectedPlugins } from '.';
import { recordRemotes } from './forms';

// --------------------------------------------------------------------------
// --- Sidebar
// --------------------------------------------------------------------------

interface SideBarItemProps {
  plugin: Params.plugin;
  selected: SelectedPlugins;
  isSet: boolean;
  remote: Forms.BufferController;
  onSelection: (
    e: React.MouseEvent<Element, MouseEvent>,
    p: Params.plugin) => void
}

function SidebarItem(props: SideBarItemProps): React.JSX.Element {
  const { plugin, selected, isSet, remote, onSelection } = props;
  const controller = Forms.useController(remote);
  const isModified = controller.hasReset() || controller.hasCommit();

  return <Item key={plugin.name}
      title={plugin.help}
      className={
        selected[0] === plugin.name ? 'options-left-form' :
        selected[1] === plugin.name ? 'options-right-form' :
        undefined
      }
      label={plugin.name}
      onSelection={(e) => onSelection(e, plugin)}
    >
      {isModified && <LED status='warning' title='Pending modification'/>}
      {isSet && <LED status='active' title='Modified fields'/>}
    </Item>;
}

interface SideBarProps {
  plugins: Params.plugin[];
  isSetElement: IsSetElement;
  selectedState: [
    SelectedPlugins,
    React.Dispatch<React.SetStateAction<SelectedPlugins>>
  ];
  remotes: recordRemotes;
}

export function OptionsSidebar(props: SideBarProps): React.JSX.Element {
  const { selectedState, isSetElement, plugins, remotes } = props;
  const [selected, setSelected] = selectedState;

  const onSelection = React.useCallback(
    (e: React.MouseEvent, p: Params.plugin) => {
    setSelected(v => {
      if(e.ctrlKey) {
        if(p.name === v[0]) return v;
        else if(p.name === v[1]) return [v[1], v[0]];
        else return [p.name, v[1]];
      } else {
        if(p.name === v[1]) return v;
        else if(p.name === v[0]) return [v[1], v[0]];
        else return [v[0], p.name];
      }
    });
  }, [setSelected]);

  return (
    <SideBar>
      <SidebarTitle label='Plugins'>
        <Dropdown control={<Button icon="HELP" title='List of plugins' />}
        ><OptionsHelp/></Dropdown>
      </SidebarTitle>
      { plugins.map(p => <SidebarItem key={p.name}
          plugin={p}
          isSet={isSetElement[p.name]}
          onSelection={onSelection}
          selected={selected}
          remote={remotes[p.name]} />
        )
      }
    </SideBar>
  );
}
