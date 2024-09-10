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

/**
   @packageDocumentation
   @module dome/colors
 */

import React from 'react';
import { useStyle, useColorTheme } from 'dome/themes';

export enum EColor {
  DEFAULT = "default",
  WHITE = 'white',
  GREY = 'grey',
  DARK = 'dark',
  PRIMARY = 'primary',
  SELECTED = 'selected',
  GREEN = 'green',
  ORANGE = 'orange',
  RED = 'red',
  YELLOW = 'yellow',
  BLUE = 'blue',
  PINK = 'pink'
}

export type TColor = `${EColor}`

type TColorVal = {
  [key in EColor]: string
}

export interface IHookColors {
  BGCOLOR: TColorVal;
  SGCOLOR: TColorVal;
  FGCOLOR: TColorVal;
  EDCOLOR: TColorVal;
}

type TColorCategory = 'bg'|'fg'|'sg'|'ed';

export function useColor(): IHookColors  {
  const style = useStyle();
  const [theme, ] = useColorTheme();

  const enum2Tcolor = (callback: (elt: EColor) => string): TColorVal => {
    return {
      ...(Object.fromEntries(
        Object.values(EColor).map((val: EColor) => [ val, callback(val)])
      )),
    } as TColorVal;
  };

  function getColorType(type: TColorCategory): TColorVal {
    return enum2Tcolor(
      (elt) => style.getPropertyValue('--graph-'+type+'-color-'+elt)
    );
  }

  const colors = React.useMemo(() => {
    return {
      // node background colors
      BGCOLOR: getColorType('bg'),
      // // cluster background colors
      SGCOLOR: getColorType('sg'),
      //  foreground colors
      FGCOLOR: getColorType('fg'),
      // // edge colors
      EDCOLOR: getColorType('ed'),
    };
  },
    /** style is dependent on theme but it is not used directly */
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [theme]
  );
  return colors;
}
