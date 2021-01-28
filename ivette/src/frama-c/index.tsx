/* --------------------------------------------------------------------------*/
/* --- Frama-C Registry                                                   ---*/
/* --------------------------------------------------------------------------*/

import React from 'react';
import * as Ivette from 'ivette';

import History from 'frama-c/kernel/History';
import Globals from 'frama-c/kernel/Globals';
import ASTview from 'frama-c/kernel/ASTview';
import ASTinfo from 'frama-c/kernel/ASTinfo';
import SourceCode from 'frama-c/kernel/SourceCode';
import Locations from 'frama-c/kernel/Locations';
import Properties from 'frama-c/kernel/Properties';

import 'frama-c/kernel/style.css';

/* --------------------------------------------------------------------------*/
/* --- Frama-C Kernel Groups                                              ---*/
/* --------------------------------------------------------------------------*/

Ivette.registerGroup({
  id: 'frama-c.kernel',
  label: 'Frama-C Kernel',
}, () => {
  Ivette.registerSidebar({ id: 'frama-c.globals', children: <Globals /> });
  Ivette.registerToolbar({ id: 'frama-c.history', children: <History /> });
  Ivette.registerComponent({
    id: 'frama-c.astview',
    label: 'AST',
    title: 'Normalized C/ACSL Source Code',
    children: <ASTview />,
  });
  Ivette.registerComponent({
    id: 'frama-c.astinfo',
    label: 'Informations',
    title: 'Informations on currently selected item',
    children: <ASTinfo />,
  });
  Ivette.registerComponent({
    id: 'frama-c.sourcecode',
    label: 'Source Code',
    title: 'C/ASCL Source Code',
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
    title: 'Status of ASCL Properties',
    children: <Properties />,
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
