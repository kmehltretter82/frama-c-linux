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

import React from 'react';
import * as Controller from './Controller';
import * as Messages from './Messages';
import * as Ivette from 'ivette';

Ivette.registerComponent({
    id: 'fc.kernel.console',
    label: 'Console',
    title: 'Frama-C Command Line',
    preferredPosition: 'AB',
    children: <Controller.RenderConsole />,
});

Ivette.registerComponent({
    id: 'fc.kernel.messages',
    label: 'Messages',
    title: 'Frama-C Messages',
    preferredPosition: 'CD',
    children: <Messages.RenderMessages />,
});

Ivette.registerView({
    id: 'ivette.console',
    label: 'Console',
    title: 'Frama-C Console & Messages',
    layout: { AB: 'fc.kernel.console', CD: 'fc.kernel.messages' },
});
