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

// --------------------------------------------------------------------------
// --- Sidebar Selector
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import { Icon } from 'dome/controls/icons';
import { SideBar } from 'dome/frame/sidebars';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import { SidebarProps, SIDEBAR } from 'ivette';
import * as State from 'ivette/state';

/* -------------------------------------------------------------------------- */
/* --- SideBar Selector                                                   --- */
/* -------------------------------------------------------------------------- */

interface SelectorProps extends SidebarProps {
  selected: string;
  setSelected: (item: string) => void;
}

function Selector(props: SelectorProps): JSX.Element {
  const { id, icon, selected, setSelected, label } = props;
  const className = classes(
    'sidebar-selector',
    'dome-color-frame',
    selected === id && 'sidebar-selector-selected',
  );
  const onClick = React.useCallback(() => setSelected(id), [setSelected, id]);
  const title = props.title ?? `${label} Sidebar`;
  const component =
    icon
    ? <Icon size={20} className="sidebar-selector-icon" id={icon}/>
    : <label className="sidebar-selector-label">{label}</label>;
  return (
    <div className={className} title={title} onClick={onClick}>
      {component}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- User Sidebar Wrapper                                               --- */
/* -------------------------------------------------------------------------- */

interface WrapperProps extends SidebarProps {
  selected: string;
}

function Wrapper(props: WrapperProps): JSX.Element {
  const className = props.selected === props.id ? '' : 'dome-erased';

  return (
    <SideBar className={className}>
      <div className="sidebar-ruler"/>
      <Catch label={props.id}>
        {props.children}
      </Catch>
    </SideBar>
  );
}

/* -------------------------------------------------------------------------- */
/* --- SideBar Main Component                                             --- */
/* -------------------------------------------------------------------------- */

export function Panel(): JSX.Element {
  const [selected, setSelected] =
    Dome.useStringSettings('ivette.sidebar.selected');

  const sidebars = State.useElements(SIDEBAR);

  // Ensures there is one selected sidebar
  React.useEffect(() => {
    if (sidebars.every((sb) => sb.id !== selected)) {
      const first = sidebars[0];
      if (first) setSelected(first.id);
    }
  }, [sidebars, selected, setSelected]);

  const items = sidebars.map((sb) => (
    <Selector
      key={sb.id}
      selected={selected}
      setSelected={setSelected}
      {...sb} />
  ));

  const wrappers = sidebars.map((sb) => (
    <Wrapper
      key={sb.id}
      selected={selected}
      {...sb}
    />
  ));

  // Hide sidebar if only one of them
  const selectorClasses = classes(
    'sidebar-items dome-color-frame',
    sidebars.length <= 1 && 'dome-erased'
  );

  return (
    <div className="sidebar-view">
      <div className={selectorClasses}>
        {items}
      </div>
      {wrappers}
    </div>
  );
}

// --------------------------------------------------------------------------
