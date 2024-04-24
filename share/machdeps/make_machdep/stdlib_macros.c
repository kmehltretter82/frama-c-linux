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

#include <limits.h>
#include <stdlib.h>

#if defined(RAND_MAX)
int rand_max_is = RAND_MAX;
#endif

/* NB: MB_LEN_MAX is the maximal value of MB_CUR_MAX;
   however, the current Frama-C libc is not equipped to
   fully deal with a non-constant MB_CUR_MAX
*/
#if defined(MB_LEN_MAX)
size_t mb_cur_max_is = ((size_t)MB_LEN_MAX);
#endif
