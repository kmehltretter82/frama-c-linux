/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2025                                               */
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

// Logic definitions related to strto* (and wcsto*) conversion functions

#ifndef __FC_STRTO_AXIOMATIC_H
#define __FC_STRTO_AXIOMATIC_H
#include "features.h"
__PUSH_FC_STDLIB
#include "__fc_define_wchar_t.h"
#include "__fc_string_axiomatic.h"

__BEGIN_DECLS

/*@
  axiomatic StrTo {
    logic ℤ str_to_integer{L}(char *s, ℤ min, ℤ max, ℤ b)
        reads s[0 .. strlen(s)];
    // Assuming that [s] points to a valid string, returns:
    // - 1 if the initial portion of [s] can be decoded as an integer in base
    //   [b], in the range [min .. max] according to the specification of
    //   strtol and similar functions (including optional whitespace,
    //   optional sign, optional prefixes, etc.);
    // - 2 if the initial portion of [s] can be decoded as an integer,
    //   but outside the range [min .. max];
    // - 0 if the initial portion of [s] cannot be converted to an integer in
    //   base [b].

    axiom StrToIntRes:
      \forall char* s, ℤ min, max, b; valid_read_string(s) ==>
        0 <= str_to_integer(s, min, max, b) <= 2;

    logic ℤ wcs_to_integer{L}(wchar_t *s, ℤ min, ℤ max, ℤ b)
        reads s[0 .. wcslen(s)];
    // Behaves just as [str_to_integer], but for wide strings

    axiom WcsToIntRes:
      \forall wchar_t* s, ℤ min, max, b; valid_read_wstring(s) ==>
        0 <= wcs_to_integer(s, min, max, b) <= 2;
  }
*/

__END_DECLS

__POP_FC_STDLIB
#endif
