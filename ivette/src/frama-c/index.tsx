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

/* --------------------------------------------------------------------------*/
/* --- Frama-C Registry                                                   ---*/
/* --------------------------------------------------------------------------*/

import React from 'react';
import * as Ivette from 'ivette';

import History from 'frama-c/kernel/History';
import Globals from 'frama-c/kernel/Globals';
import Status from 'frama-c/kernel/Status';
import ASTinfo from 'frama-c/kernel/ASTinfo';
import ASTview from 'frama-c/kernel/ASTview';
import SourceCode from 'frama-c/kernel/SourceCode';
import PivotTable from 'frama-c/kernel/PivotTable';
import Locations from 'frama-c/kernel/Locations';
import Properties from 'frama-c/kernel/Properties';
import Messages from 'frama-c/kernel/Messages';
import * as db from '../sandbox/doublebar';

import compIco from '../sandbox/icons/component.png';
import fileIco from '../sandbox/icons/file.png';
import folderIco from '../sandbox/icons/folder.png';
import funcIco from '../sandbox/icons/function.png';

import 'frama-c/kernel/style.css';

import * as Menu from 'frama-c/menu';

import * as Laboratory from '../renderer/Laboratory';

Menu.init();

/* --------------------------------------------------------------------------*/
/* --- Frama-C Kernel Groups                                              ---*/
/* --------------------------------------------------------------------------*/

Ivette.registerGroup({
  id: 'frama-c.kernel',
  label: 'Frama-C Kernel',
}, () => {
  Ivette.registerDoublebar({
    id: 'frama-c.doublebar',
    children: <db.DoubleBar />
  });
  Ivette.registerToolbar({ id: 'frama-c.history', children: <History /> });
  Ivette.registerStatusbar({ id: 'frama-c.message', children: <Status /> });
  Ivette.registerComponent({
    id: 'frama-c.astinfo',
    label: 'Inspector',
    title: 'Contextual information on selected AST elements',
    children: <ASTinfo />
  });
  Ivette.registerComponent({
    id: 'frama-c.astview',
    label: 'AST',
    title: 'Normalized C/ACSL Source Code',
    children: <ASTview />,
  });
  Ivette.registerComponent({
    id: 'frama-c.sourcecode',
    label: 'Source Code',
    title: 'C/ACSL Source Code',
    children: <SourceCode />,
  });
  Ivette.registerComponent({
    id: 'frama-c.locations',
    label: 'Locations',
    title: 'Selected list of locations',
    children: <Locations />,
  });
  Ivette.registerComponent({
    id: 'frama-c.properties',
    label: 'Properties',
    title: 'Status of ACSL Properties',
    children: <Properties />,
  });
  Ivette.registerComponent({
    id: 'frama-c.messages',
    label: 'Messages',
    title: 'Messages emitted by Frama-C',
    children: <Messages />,
  });
  Ivette.registerComponent({
    id: 'frama-c.pivottable',
    label: 'Pivot Table',
    title: 'Pivot Table',
    children: <PivotTable />,
  });
});

/* --------------------------------------------------------------------------*/
/* --- Frama-C Plug-ins Group                                             ---*/
/* --------------------------------------------------------------------------*/

Ivette.registerGroup({
  id: 'frama-c.plugins',
  label: 'Frama-C Plug-ins',
});

/* --------------------------------------------------------------------------*/
/* --- Frama-C Views                                                      ---*/
/* --------------------------------------------------------------------------*/

Ivette.registerView({
  id: 'source',
  rank: 1,
  label: 'Source Code',
  defaultView: true,
  layout: [
    ['frama-c.astview', 'frama-c.sourcecode'],
    'frama-c.astinfo',
  ],
});

Ivette.registerView({
  id: 'properties',
  rank: 2,
  label: 'Properties',
  layout: [
    ['frama-c.astview', 'frama-c.sourcecode'],
    'frama-c.properties',
  ],
});

Ivette.registerView({
  id: 'pivot-table',
  rank: 6,
  label: 'Pivot Table',
  layout: [
    ['frama-c.pivottable'],
  ],
});

/* --------------------------------------------------------------------------*/
/* --- Frama-C Categories                                                 ---*/
/* --------------------------------------------------------------------------*/

Ivette.registerCategory({
  title: "Functions",
  iconPath: funcIco,
  subMenu: <Globals />
});
Ivette.registerCategory({
  title: "File",
  iconPath: fileIco,
  subMenu: db.secondaryMenu1
});
Ivette.registerCategory({
  title: "Folder",
  iconPath: folderIco,
  subMenu: db.secondaryMenu2
});
Ivette.registerCategory({
  title: "Functions",
  iconPath: compIco,
  subMenu: <Laboratory.LabView
    customize={true}
    settings="frama-c.labview"
/>
});

/* --------------------------------------------------------------------------*/
