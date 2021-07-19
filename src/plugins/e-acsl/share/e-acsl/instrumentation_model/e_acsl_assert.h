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
 **************************************************************************/

#ifndef E_ACSL_ASSERT_H
#define E_ACSL_ASSERT_H

#include "../internals/e_acsl_alias.h"

#define eacsl_runtime_sound_verdict export_alias(sound_verdict)
#define eacsl_assert_data_t         export_alias(assert_data_t)
#define eacsl_runtime_assert        export_alias(assert)

/*! E-ACSL instrumentation automatically sets this global to 0 if its verdict
    becomes unsound.
    TODO: may only happen for annotations containing memory-related properties.
    For arithmetic properties, the verdict is always sound (?). */
extern int __attribute__((FC_BUILTIN)) eacsl_runtime_sound_verdict;

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
} __attribute__((__FC_BUILTIN__)) eacsl_assert_data_t;

/*! \brief Runtime assertion verifying a given predicate
 *  \param predicate integer code of a predicate
 *  \param data context data for the predicate. */
/*@ requires \valid_read(data) && \initialized(data);
  @ assigns \nothing;
  @ behavior blocking:
  @   assumes data->blocking != 0;
  @   requires predicate != 0;
  @ behavior non_blocking:
  @   assumes data->blocking == 0;
  @   check requires predicate != 0;
  @ complete behaviors;
  @ disjoint behaviors; */
void eacsl_runtime_assert(int predicate, eacsl_assert_data_t *data)
    __attribute__((FC_BUILTIN));

#endif // E_ACSL_ASSERT_H
