/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2017                                               */
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
 * \file  e_acsl_memory_mmodel.c
 * \brief Configuration macros and RTL assembly
***************************************************************************/

#include <sys/mman.h>
#include <errno.h>
#include <sys/resource.h>

#include "e_acsl_string.h"
#include "e_acsl_bits.h"
#include "e_acsl_printf.h"
#include "e_acsl_debug.h"
#include "e_acsl_assert.h"
#include "e_acsl_malloc.h"
#include "e_acsl_safe_locations.h"

/* Memory model settings
 *    Memory model:
 *      E_ACSL_BITTREE_MMODEL - use Patricia-trie (tree-based) memory model, or
 *      E_ACSL_SEGMENT_MMODEL - use segment-based (shadow) memory model
 *    Verbosity level:
 *      E_ACSL_VERBOSE - is set puts an executable in verbose mode (which
 *        may print some extra messages
 *    Debug Features:
 *      E_ACSL_DEBUG - enable debug features in RTL
 *      E_ACSL_DEBUG_VERBOSE - verbose debug output (via DVLOG macro)
 *      E_ACSL_DEBUG_LOG - name of the log file where debug messages are
 *        output. The file name should be unquoted string with '-'
 *        (set by default) indicating a standard stream
 *    Validity:
 *      E_ACSL_WEAK_VALIDITY - use notion of weak validity
 *        Given an expression `(p+i)`, where `p` is a pointer and `i` is an
 *        integer offset weak validity indicates that `(p+i)` is valid if it
 *        belongs to memory allocation. In strong validity `(p+i)` is valid
 *        iff both `p` and `(p+i)` belong to memory allocation and to one
 *        memory block.
 *    Temporal analysis:
 *      E_ACSL_TEMPORAL - enable temporal analysis in RTL
 *    Assertions:
 *      E_ACSL_NO_ASSERT_FAIL - do not issue abort signal of E-ACSL
 *        assertion failure
 *    Shadow spaces (only for segment model):
 *      E_ACSL_STACK_SIZE - size (in MB) of the tracked program stack
 *      E_ACSL_HEAP_SIZE - size (in MB) of the tracked program heap
*/

/* Print a header indicating current configuration of a run to STDIN. */
static void describe_run();

/* Select memory model, either segment-based or bittree-based model should
   be defined */
#if defined E_ACSL_SEGMENT_MMODEL
#  include "segment_model/e_acsl_segment_mmodel.c"
#elif defined E_ACSL_BITTREE_MMODEL
#  include "bittree_model/e_acsl_bittree_mmodel.c"
#else
#  error "No E-ACSL memory model defined. Aborting compilation"
#endif

#ifdef E_ACSL_WEAK_VALIDITY
# define E_ACSL_VALIDITY_DESC "weak"
#else
# define E_ACSL_VALIDITY_DESC "strong"
#endif

/* Print basic configuration before each run */
static void describe_run() {
#if defined(E_ACSL_VERBOSE) || defined(E_ACSL_DEBUG)
  printf("/* ========================================================= */\n");
  printf(" * E-ACSL instrumented run\n" );
#ifdef E_ACSL_SEGMENT_MMODEL
  printf(" * Memory tracking: shadow memory with\n" );
  printf(" *   Heap  %d MB\n", E_ACSL_HEAP_SIZE);
  printf(" *   Stack %d MB\n", E_ACSL_STACK_SIZE);
#else
  printf(" * Memory tracking: patricia trie\n" );
#endif
  printf(" * Execution mode:  %s\n", E_ACSL_DEBUG_DESC);
  printf(" * Assertions mode: %s\n", E_ACSL_ASSERT_NO_FAIL_DESC);
  printf(" * Validity notion: %s\n", E_ACSL_VALIDITY_DESC);
  printf("/* ========================================================= */\n");
#endif
}
