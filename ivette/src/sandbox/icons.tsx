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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Icons Gallery                                              --- */
/* --- Only appears in DEVEL mode.                                        --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import { Label, Code } from 'dome/controls/labels';
import { IconData, forEach } from 'dome/controls/icons';
import { Section } from 'dome/frame/sidebars';
import { Scroll, Grid } from 'dome/layout/boxes';
import { registerSandbox } from 'ivette';

/* -------------------------------------------------------------------------- */
/* --- Use Text                                                           --- */
/* -------------------------------------------------------------------------- */

function Gallery(): JSX.Element {
  const gallery : Map<string, JSX.Element[]> = new Map();
  forEach((icon: IconData) => {
    const { id, title, section='Custom Icons' } = icon;
    let icons = gallery.get(section);
    if (icons === undefined) {
      icons = [];
      gallery.set(section, icons);
    }
    icons.push(<Code key={'C'+id} icon={id} label={id} />);
    icons.push(<Label key={'L'+id} label={title} />);
  });
  const sections : JSX.Element[] = [];
  gallery.forEach((icons, section) => {
    sections.push(
      <Section key={section} defaultUnfold label={section}>
        <Grid style={{ paddingLeft: 24 }} columns="auto auto">{icons}</Grid>
      </Section>
    );
  });
  return <Scroll>{sections}</Scroll>;
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.icons',
  label: 'Icons Gallery',
  children: <Gallery />,
});

/* -------------------------------------------------------------------------- */
