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
 * \brief E-ACSL data for assertions.
 **************************************************************************/

#ifndef E_ACSL_ASSERT_DATA_H
#define E_ACSL_ASSERT_DATA_H

#include "../internals/e_acsl_alias.h"

#define eacsl_assert_data_t export_alias(assert_data_t)

/*! Data holding context information for E-ACSL assertions. */
typedef struct eacsl_assert_data_t {
  /*! integer representing if the assertion is blocking or not */
  int blocking;
  /*! C string representing a kind of annotation (e.g., "Assertion") */
  const char *kind;
  /*! stringified predicate */
  const char *pred_txt;
  /*! un-instrumented file of predicate placement */
  const char *file;
  /*! function of predicate placement in the un-instrumented file */
  const char *fct;
  /*! line of predicate placement in the un-instrumented file */
  int line;
  /*! values contributing to the predicate */
  void *values;
} __attribute__((FC_BUILTIN)) eacsl_assert_data_t;

#endif // E_ACSL_ASSERT_DATA_H
