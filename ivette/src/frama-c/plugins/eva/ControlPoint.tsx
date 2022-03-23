/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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
import BeforeImage from './img/before.svg';
import AfterImage from './img/after.svg';
import ThenImage from './img/then.svg';
import ElseImage from './img/else.svg';

type controlPointKind = 'before' | 'after' | 'then' | 'else';

function imageSource(kind: controlPointKind): string {
  switch (kind) {
    case 'before': return BeforeImage;
    case 'after': return AfterImage;
    case 'then': return ThenImage;
    case 'else': return ElseImage;
  }
}

function imageTitle(kind: controlPointKind): string {
  switch (kind) {
    case 'before': return 'Before the selected statement';
    case 'after': return 'After the selected statement';
    case 'then': return 'Inside the "then" branch';
    case 'else': return 'Inside the "else" branch';
  }
}

export default function ({ kind }: { kind: controlPointKind}) {
  return (
    <img
      style={{ verticalAlign: 'middle' }}
      src={imageSource(kind)}
      height="18px"
      width="18px"
      title={imageTitle(kind)}
      alt={imageTitle(kind)}
    />
  );
}
