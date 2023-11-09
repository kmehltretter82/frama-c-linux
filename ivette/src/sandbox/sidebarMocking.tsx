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
import * as Ivette from 'ivette';
import { registerSandbox } from 'ivette';
import * as SideBar from './sidebar';
import fileIco from './icons/file.png';
import folderIco from './icons/folder.png';

/* -------------------------------------------------------------------------- */
/* --- Mocking                                                            --- */
/* -------------------------------------------------------------------------- */

export function SideBarMocking(): JSX.Element {
    Ivette.registerCategory({
        id: "file",
        label: "File",
        iconPath: fileIco,
        children: SideBar.secondaryMenu1
      });
      Ivette.registerCategory({
        id: "folder",
        label: "Folder",
        iconPath: folderIco,
        children: SideBar.secondaryMenu2
      });
      Ivette.registerCategory({
        id: "lorem",
        label: "lorem",
        children: SideBar.secondaryMenu1
      });
      Ivette.registerCategory({
        id: "ipsum",
        label: "ipsum",
        children: SideBar.secondaryMenu2
      });

    return (
        <SideBar.SideBar></SideBar.SideBar>
    );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */


registerSandbox({
    id: 'sandbox.sidebar-mocking',
    label: 'Sidebar Mocking',
    children: <SideBarMocking />,
  });

/* -------------------------------------------------------------------------- */
