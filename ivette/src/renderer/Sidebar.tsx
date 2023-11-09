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
import { SIDEBAR } from 'ivette';
import * as Ext from './Extensions';

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

export function Panel(): JSX.Element {
  const sidebars = Ext.useElements(SIDEBAR);
  const items = sidebars.map((sb) => (
    <ul key={sb.id}>
      {sb.label}
    </ul>
  ));
  return (
    <div>
      <div className='sidebar-ruler' />
      Side Bar Selector
      <ul>
        {items}
      </ul>
    </div>
  );
}

// --------------------------------------------------------------------------
