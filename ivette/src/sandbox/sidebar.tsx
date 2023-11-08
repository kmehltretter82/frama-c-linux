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


import React, { useState } from 'react';
import { classes } from 'dome/misc/utils';
import { Item, Section } from "dome/frame/sidebars";
import { Catch } from 'dome/errors';
import { SideBarCategoryProps, registerSandbox } from 'ivette';
import './style.css';

/* -------------------------------------------------------------------------- */
/* --- Mocking                                                            --- */
/* -------------------------------------------------------------------------- */

interface Category extends SideBarCategoryProps{
  display: boolean;
}

const itemsSection1 = (
  <div>
    <Item
      className="class1.1"
      label="item 1.1-l"
      title="item 1.1-t"
      selected={false}
    />
    <Item
      className="class1.2"
      label="item 1.2-l"
      title="item 1.2-t"
      selected={false}
    />
    <Item
      className="class1.3"
      label="item 1.3-l"
      title="item 1.3-t"
      selected={false}
    />
  </div>
);

const itemsSection2 = (
  <div>
    <Item
      className="class2.1"
      label="item 2.1-l"
      title="item 2.1-t"
      selected={false}
    />
    <Item
      className="class2.2"
      label="item 2.2-l"
      title="item 2.2-t"
      selected={false}
    />
    <Item
      className="class2.3"
      label="item 2.3-l"
      title="item 2.3-t"
      selected={false}
      />
  </div>
);

export const secondaryMenu1 = (
  <>
    <Section
      label="label section1"
      title="title section1"
      defaultUnfold
      settings="frama-c.sidebar.updated"
      className='globals-function-section'
    >
      {itemsSection1}
    </Section>
    <Section
      label="label section2"
      title="title section2"
      defaultUnfold={false}
      settings="frama-c.sidebar.updated2"
      className='globals-function-section'
    >
    {itemsSection2}
  </Section>
</>
);

export const secondaryMenu2 = (
  <>
    <Section
      label="label section1"
      title="title section1"
      defaultUnfold={false}
      settings="frama-c.sidebar.updated2"
      className='globals-function-section'
    >
      {itemsSection2}
    </Section>
  </>
);

const categories: Category[] = [];

export function registerCategory(item: SideBarCategoryProps): void {
  categories.push({ ...item, display: false });
}

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
    'dome-xSideBar',
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
      <div className={classNameSecondary +
      (categories[selectedCategory].display === false ? 'dome-erased' : '')}>
        {categories[selectedCategory].children}
      </div>
    </div>
    </Catch>
  );
}


/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.sidebar',
  label: 'Sidebar',
  children: <SideBar />,
});

/* -------------------------------------------------------------------------- */
