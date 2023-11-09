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


import React from 'react';
import { Item, Section } from "dome/frame/sidebars";
import * as Ivette from 'ivette';

/* -------------------------------------------------------------------------- */
/* --- Mocking                                                            --- */
/* -------------------------------------------------------------------------- */

Ivette.registerSidebar({
  id: 'sandbox.sidebar.a',
  label: 'SandA',
  children:
    <>
      <Section label='Section A.1'>
        <Item label='Item A.1.1' />
        <Item label='Item A.1.2' />
        <Item label='Item A.1.3' />
        <Item label='Item A.1.4' />
      </Section>
      <Section label='Section A.2'>
        <Item label='Item A.2.1' />
        <Item label='Item A.2.2' />
        <Item label='Item A.2.3' />
        <Item label='Item A.2.4' />
      </Section>
    </>
});

Ivette.registerSidebar({
  id: 'sandbox.sidebar.b',
  label: 'SandB',
  children:
    <>
      <Section label='Section B.1'>
        <Item label='Item B.1.1' />
        <Item label='Item B.1.2' />
        <Item label='Item B.1.3' />
        <Item label='Item B.1.4' />
      </Section>
      <Section label='Section B.2'>
        <Item label='Item B.2.1' />
        <Item label='Item B.2.2' />
        <Item label='Item B.2.3' />
        <Item label='Item B.2.4' />
      </Section>
    </>
});

/* -------------------------------------------------------------------------- */
