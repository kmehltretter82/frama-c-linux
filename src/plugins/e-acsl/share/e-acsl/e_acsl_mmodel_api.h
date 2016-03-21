/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2016                                               */
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
/*  for more details (enclosed in the file license/LGPLv2.1).             */
/*                                                                        */
/**************************************************************************/

/*! ***********************************************************************
 * \file   e_acsl_mmodel_api.h
 * \brief  Public C API of E-ACSL Runtime Library
 *
 * Functions and variables with non-static linkage used for instrumentation.
***************************************************************************/

#ifndef E_ACSL_MMODEL
#define E_ACSL_MMODEL

#include <stddef.h>

/*! \brief Runtime assertion verifying a predicate
 *  \param pred  integer code of a predicate
 *  \param kind  a C string representing an annotation's
 *    kind (e.g., "Assertion")
 *  \param fct
 *  \param pred_txt  stringified predicate
 *  \param line  line number of the predicate placement in the
 *    un-instrumented file */
/*@ requires pred != 0;
  @ assigns \nothing; */
void e_acsl_assert(int pred, char *kind, char *fct, char *pred_txt, int line)
  __attribute__((FC_BUILTIN));

/*! \brief Drop-in replacement for \p malloc with memory tracking enabled.
 *
 * For further information, see \p malloc(3). */
/*@ assigns \result \from size; */
void * __malloc(size_t size)
  __attribute__((FC_BUILTIN)) ;

/*! \brief Drop-in replacement for \p calloc with memory tracking enabled.
 *
 * For further information, see \p calloc(3). */
/*@ assigns \result \from nbr_elt,size_elt; */
void * __calloc(size_t nbr_elt, size_t size_elt)
  __attribute__((FC_BUILTIN));

/*! \brief Drop-in replacement for \p realloc with memory tracking enabled.
 *
 * For further information, see realloc(3) */
/*@ assigns \result \from *(((char*)ptr)+(0..size-1)); */
void * __realloc(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*! \brief Drop-in replacement for \p free with memory tracking enabled.
 *
 * For further information, see \p free(3). */
/*@ assigns *((char*)ptr) \from ptr; */
void __free(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Store stack or globally-allocated memory block
 * starting at an address given by \p ptr.
 *
 * \param ptr base address of the tracked memory block
 * \param size size of the tracked block in bytes */
/*@ assigns \result \from *(((char*)ptr)+(0..size-1)); */
void * __store_block(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*! \brief Remove a memory block which base address is \p ptr from tracking. */
/*@ assigns \nothing; */
void __delete_block(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Mark the \p size bytes starting at an address given by \p ptr as
 * initialized. */
/*@ assigns \nothing; */
void __initialize(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*! \brief Mark all bytes belonging to a memory block which start address is
 * given by \p ptr as initialized. */
/*@ assigns \nothing; */
void __full_init(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Mark a memory block which start address is given by \ptr as
 * read-only. */
/*@ assigns \nothing; */
void __readonly(void * ptr)
  __attribute__((FC_BUILTIN));

/* ****************** */
/* E-ACSL annotations */
/* ****************** */

/*!\brief Implementation of the \b \\freeable predicate of E-ACSL.
 *
 * Evaluate to a non-zero value if \p ptr points to a start address of
 * a block allocated via \p malloc, \p calloc or \p realloc. */
/*@ assigns \result \from ptr; */
int __freeable(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Implementation of the \b \\valid predicate of E-ACSL.
 *
 * Return a non-zero value if the first \p size bytes starting at an address given
 * by \p ptr are readable and writable and 0 otherwise. */
/*@ ensures \result == 0 || \result == 1;
  @ ensures \result == 1 ==> \valid(((char *)ptr)+(0..size-1));
  @ assigns \result \from *(((char*)ptr)+(0..size-1)); */
int __valid(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*! \brief Implementation of the \b \\valid_read predicate of E-ACSL.
 *
 * Return a non-zero value if the first \p size bytes starting at an address
 * given by \p ptr are readable and 0 otherwise. */
/*@ ensures \result == 0 || \result == 1;
  @ ensures \result == 1 ==> \valid_read(((char *)ptr)+(0..size-1));
  @ assigns \result \from *(((char*)ptr)+(0..size-1)); */
int __valid_read(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*! \brief Implementation of the \b \\base_addr predicate of E-ACSL.
 *
 * Return the base address of the memory block containing an address given
 * by \p ptr */
/*@ ensures \result == \base_addr(ptr);
  @ assigns \result \from ptr; */
void * __base_addr(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Implementation of the \b \\block_length predicate of E-ACSL.
 *
 * Return the byte length of the memory block of the block containing a memory
 * address given by \p ptr */
/*@ ensures \result == \block_length(ptr);
  @ assigns \result \from ptr; */
size_t __block_length(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Implementation of the \b \\offset predicate of E-ACSL.
 *
 * Return the byte offset of address given by \p ptr within a memory blocks
 * it belongs to */
/* FIXME: The return type of __offset should be changed to size_t.
 * In the current E-ACSL/Frama-C implementation, however, this change
 * leads to a Frama-C failure. */
/*@ ensures \result == \offset(ptr);
  @ assigns \result \from ptr; */
int __offset(void * ptr)
  __attribute__((FC_BUILTIN));

/*! \brief Implementation of the \b \\initialized predicate of E-ACSL.
 *
 * Return a non-zero value if \p size bytes starting from an address given by
 * \p ptr are initialized and zero otherwise. */
/*@ ensures \result == 0 || \result == 1;
  @ ensures \result == 1 ==> \initialized(((char *)ptr)+(0..size-1));
  @ assigns \result \from *(((char*)ptr)+(0..size-1)); */
int __initialized(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*@ ghost int extern __e_acsl_internal_heap; */

/*! \brief Clean-up memory tracking state before a program's termination. */
/*@ assigns \nothing; */
void __e_acsl_memory_clean(void)
  __attribute__((FC_BUILTIN));

/*! \brief Initialize memory tracking state.
 *
 * Called before any other statement in \p main */
/*@ assigns \nothing; */
void __e_acsl_memory_init(int *argc_ref, char ***argv, size_t ptr_size)
  __attribute__((FC_BUILTIN));

/*! \brief Return the cumulative size (in bytes) of tracked heap allocation. */
/*@ assigns \result \from __e_acsl_internal_heap; */
size_t __get_heap_size(void)
  __attribute__((FC_BUILTIN));

/*! \brief A variable holding a cumulative size (in bytes) of tracked
 * heap allocation. */
extern size_t __heap_size;

/*@ predicate diffSize{L1,L2}(integer i) =
  \at(__heap_size, L1) - \at(__heap_size, L2) == i;
*/
#endif
