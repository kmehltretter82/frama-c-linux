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
import { DoubleBarCategoryProps, registerSandbox } from 'ivette';

/* -------------------------------------------------------------------------- */
/* --- Mocking                                                            --- */
/* -------------------------------------------------------------------------- */

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

const categories: DoubleBarCategoryProps[] = [];

export function registerCategory(item: DoubleBarCategoryProps): void {
  categories.push(item);
}

export function DoubleBar(): JSX.Element {
  const classNameGlobal = classes(
    'dome-xDoubleBar',
  );

  const classNamePrime = classes(
    'dome-xDoubleBar-primary',
    'dome-color-frame',
  );

  const classNamePrimeIcon = classes(
    'dome-xDoubleBar-primary-icon'
  );

  const classNameSecondary = classes(
    'dome-xDoubleBar-secondary',
    'dome-color-frame',
  );

  const [selectedCategory, setSelectedCategory] = useState(0);

  return (
    <div className={classNameGlobal}>
      <div className={classNamePrime}>
        <>
          {categories.map((item, key) => (
            <div key={key}>
              <img
              className={classNamePrimeIcon}
              src={item.iconPath}
              alt={item.title}
              title={item.title}
              onClick={
                () => {
                  selectedCategory !== key ?
                  setSelectedCategory(key) :
                  setSelectedCategory(-1);
                }
              }
              />
              <br/>
            </div>
          ))}
        </>
      </div>
      <div className={classNameSecondary}>
        {selectedCategory !== -1 &&
        categories[selectedCategory].subMenu}
      </div>
    </div>
  );
}


/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.doublebar',
  label: 'Double Bar',
  children: <DoubleBar />,
});

/* -------------------------------------------------------------------------- */
