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
 * \brief E-ACSL assertions and abort statements.
***************************************************************************/

#ifndef E_ACSL_ASSERT_H
#define E_ACSL_ASSERT_H

#include "../internals/e_acsl_alias.h"

#define eacsl_runtime_sound_verdict export_alias(sound_verdict)
#define eacsl_runtime_assert        export_alias(assert)

/*! E-ACSL instrumentation automatically sets this global to 0 if its verdict
    becomes unsound.
    TODO: may only happen for annotations containing memory-related properties.
    For arithmetic properties, the verdict is always sound (?). */
extern int eacsl_runtime_sound_verdict;

/*! \brief Runtime assertion verifying a given predicate
 *  \param pred  integer code of a predicate
 *  \param kind  C string representing a kind an annotation (e.g., "Assertion")
 *  \param fct
 *  \param pred_txt  stringified predicate
 *  \param file un-instrumented file of predicate placement
 *  \param line line of predicate placement in the un-instrumented file */
/*@ requires pred != 0;
  @ assigns \nothing; */
void eacsl_runtime_assert(int pred, const char *kind, const char *fct,
    const char *pred_txt, const char * file, int line)
  __attribute__((FC_BUILTIN));

#endif // E_ACSL_ASSERT_H