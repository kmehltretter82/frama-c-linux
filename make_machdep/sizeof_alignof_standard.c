/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2023                                               */
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

#include "make_machdep_common.h"

/* We want to obtain values produced by the compiler.
   In an ideal scenario, we are able to execute the binary, so we can just use
   printf(). However, when cross-compiling, we may be unable to run the program.
   Even worse, we may lack a proper runtime, and thus simply obtaining an
   executable may be impossible.
   However, we don't really need it: having an object file (with symbols) is
   usually enough.

   We store the values in global variables, since at the very least we can
   examine the object file to retrieve the data.
*/

unsigned char sizeof_short = sizeof(short);
unsigned char sizeof_int = sizeof(int);
unsigned char sizeof_long = sizeof(long);
unsigned char sizeof_longlong = sizeof(long long);
unsigned char sizeof_ptr = sizeof(void*);
unsigned char sizeof_float = sizeof(float);
unsigned char sizeof_double = sizeof(double);

unsigned char alignof_short = ALIGNOF(short);
unsigned char alignof_int = ALIGNOF(int);
unsigned char alignof_long = ALIGNOF(long);
unsigned char alignof_longlong = ALIGNOF(long long);
unsigned char alignof_ptr = ALIGNOF(void*);
unsigned char alignof_float = ALIGNOF(float);
unsigned char alignof_double = ALIGNOF(double);
