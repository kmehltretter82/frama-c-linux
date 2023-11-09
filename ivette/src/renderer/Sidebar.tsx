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
import { SidebarProps, SIDEBAR } from 'ivette';
import * as Ext from './Extensions';

// TODO: remove sandbox/style.css
// TODO: add classes in `./style.css` under name .sidebar-xxx if necessary
// TODO: incorporate previous dev in comments below into draft (Cf. TODO)

/*
   export function SideBar(): JSX.Element {
   const classNameGlobal = classes(
   'dome-xSideBar-double',
   );

   const classNamePrime = classes(
   'dome-xSideBar-double-primary',
   'dome-color-frame',
   );

   const classNamePrimeIcon = classes(
   'dome-xSideBar-double-primary-icon'
   );

   const classNamePrimeLabel = classes(
   'dome-xSideBar-double-primary-label'
   );

   const classNameSecondary = classes(
   'dome-xSideBar-double-secondary',
   'dome-color-frame',
   );

   const [selectedCategory, setSelectedCategory] = useState(0);

   function updateSelected(key: number): void {
   setSelectedCategory(key);
   categories[key].display = true;
   }

   return (
   <Catch label={"dome-xSideBar-double-catch"}>
   <div className={classNameGlobal}>
   <div className={classNamePrime}>
   <>
   {categories.map((item, key) => (
   <div key={key}>
   {item.iconPath ?
   <img
   className={classNamePrimeIcon}
   id={item.id}
   src={item.iconPath}
   alt={item.label}
   title={item.label}
   onClick={
   () => updateSelected(key)
   }
   />
   :
   <label
   className={classNamePrimeLabel}
   id={item.id}
   onClick={
   () => updateSelected(key)
   }
   >
   {item.label.slice(0, 4).toLocaleUpperCase()}
   </label>
   }
   <br/>
   </div>
   ))}
   </>
   </div>
   <sb.SideBar className={classNameSecondary +
   (categories[selectedCategory].display === false ? 'dome-erased' : '')}>
   {categories[selectedCategory].children}
   </sb.SideBar>
   </div>
   </Catch>
   );
   }
 */

/* -------------------------------------------------------------------------- */
/* --- SideBar Selector                                                   --- */
/* -------------------------------------------------------------------------- */

interface SelectorProps extends SidebarProps {
  selected: string;
  setSelected: (item: string) => void;
}

function Selector(props: SelectorProps): JSX.Element {
  const { id, selected, setSelected, label, title } = props;
  // TODO: redesign this by incorporating some stuff from previous dev
  return (
    <li title={title} onClick={() => setSelected(id)}>
      {selected === id ? '(*)' : '(-)'} {label}
    </li>
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
  // TODO: redesign this by incorporating some stuff drom previous dev
  return (
    <div>
      <div className='sidebar-ruler' />
      Side Bar Selector
      <ul>
        {items}
      </ul>
      {wrappers}
    </div>
  );
}

// --------------------------------------------------------------------------
