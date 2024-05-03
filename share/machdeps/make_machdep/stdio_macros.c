/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2024                                               */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  you can redistribute it and/or modify it under the terms of the GNU   */
/*  Lesser General Public License as published by the Free Software       */
/*  Foundation, version 2.1.                                              */
/*                                                                        */
/*  It is distributed in the hope that it will be useful,                 */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*  GNU Lesser General Public License for more details.                   */
/*                                                                        */
/*  See the GNU Lesser General Public License version 2.1                 */
/*  for more details (enclosed in the file licenses/LGPLv2.1).            */
/*                                                                        */
/**************************************************************************/

#include <stdio.h>

#if defined(BUFSIZ)
int bufsiz_is = BUFSIZ;
#endif
#if defined(EOF)
int eof_is = EOF;
#endif
#if defined(FOPEN_MAX)
int fopen_max_is = FOPEN_MAX;
#endif
#if defined(FILENAME_MAX)
int filename_max_is = FILENAME_MAX;
#endif
#if defined(L_tmpnam)
int l_tmpnam_is = L_tmpnam;
#endif
#if defined(TMP_MAX)
int tmp_max_is = TMP_MAX;
#endif
