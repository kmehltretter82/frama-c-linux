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

// --------------------------------------------------------------------------
// --- Sidebar Selector
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import { SideBar } from 'dome/frame/sidebars';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import { SidebarProps, SIDEBAR } from 'ivette';
import * as Ext from './Extensions';

/* -------------------------------------------------------------------------- */
/* --- SideBar Selector                                                   --- */
/* -------------------------------------------------------------------------- */

interface SelectorProps extends SidebarProps {
  selected: string;
  setSelected: (item: string) => void;
}

function Selector(props: SelectorProps): JSX.Element {
  const { id, iconPath, setSelected, label, title } = props;

  const classNameSelector = classes(
    'sidebar-selector',
    'dome-color-frame',
    );

    const classNameSelectorIcon = classes(
    'sidebar-selector-icon'
    );

    const classNameSelectorLabel = classes(
    'sidebar-selector-label'
    );

  return (
    <>
      <div className={classNameSelector}>
        {iconPath ?
          <img
          className={classNameSelectorIcon}
          id={id}
          src={iconPath}
          alt={label}
          title={title}
          onClick={
            () => setSelected(id)
          }
          />
          :
          <label
          className={classNameSelectorLabel}
          id={id}
          onClick={
            () => setSelected(id)
          }
          >
            {label.slice(0, 4).toLocaleUpperCase()}
          </label>
        }
        <br/>
      </div>
    </>
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
  const classNameRuler = classes(
    'sidebar-ruler',
    );
  const classNameItems = classes(
    'sidebar-items',
    'dome-color-frame',
    );
  const [selected, setSelected] =
    Dome.useStringSettings('ivette.sidebar.selected');
  const sidebars = Ext.useElements(SIDEBAR);
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

  return (
    <div className={classNameRuler}>
      <ul className={classNameItems}>
        {items}
      </ul>
      {wrappers}
    </div>
  );
}

// --------------------------------------------------------------------------
