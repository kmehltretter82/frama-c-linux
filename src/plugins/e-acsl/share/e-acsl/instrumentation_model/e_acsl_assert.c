/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2020                                               */
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

/*! ***********************************************************************
 * \file
 * \brief E-ACSL assertions and abort statements implementation.
***************************************************************************/

#include <stdlib.h>

#include "../internals/e_acsl_private_assert.h"
#include "../internals/e_acsl_rtl_io.h"

#include "e_acsl_assert.h"

int runtime_sound_verdict = 1;

#ifndef E_ACSL_EXTERNAL_ASSERT
/*! \brief Default implementation of E-ACSL runtime assertions */
void runtime_assert(int predicate, const char *kind, const char *fct,
    const char *pred_txt, const char * file, int line) {
  if (runtime_sound_verdict) {
    if (! predicate) {
      STDERR("%s: In function '%s'\n"
             "%s:%d: Error: %s failed:\n"
             "\tThe failing predicate is:\n"
             "\t%s.\n",
             file, fct, file, line, kind, pred_txt);
#ifndef E_ACSL_NO_ASSERT_FAIL /* Do fail on assertions */
#ifdef E_ACSL_FAIL_EXITCODE /* Fail by exit with a given code */
      exit(E_ACSL_FAIL_EXITCODE);
#else
      raise_abort(file, line); /* Raise abort signal */
#endif
#endif
    }
  } else
    STDERR("%s: In function '%s'\n"
           "%s:%d: Warning: no sound verdict for %s (guess: %s).\n"
           "\tthe considered predicate is:\n"
           "\t%s\n",
           file, fct, file, line, kind, predicate ? "ok": "FAIL", pred_txt);
}
#endif
