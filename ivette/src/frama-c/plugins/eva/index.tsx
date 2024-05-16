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

// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

import * as Ivette from 'ivette';
import './valuetable';
import './Summary';
import './Coverage';
import './DomainStates';
import './style.css';

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

Ivette.registerGroup({
  id: 'fc.eva',
  label: 'Eva Plugin'
});

Ivette.registerView({
  id: 'fc.eva.summary',
  label: 'Eva Summary',
  layout: {
    'A': 'fc.eva.summary',
    'B': 'fc.eva.coverage',
    'CD': 'fc.kernel.messages',
  },
});

Ivette.registerView({
  id: 'fc.eva.values',
  label: 'Eva Values',
  layout: {
    'A': 'fc.kernel.astview',
    'B': 'fc.kernel.astinfo',
    'CD': 'fc.eva.values',
  }
});

// --------------------------------------------------------------------------
