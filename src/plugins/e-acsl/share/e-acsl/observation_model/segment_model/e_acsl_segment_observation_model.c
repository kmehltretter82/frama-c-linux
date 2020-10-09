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
 * \brief  Implementation of E-ACSL public API for a segment (shadow) memory
 *   model. See e_acsl.h for details.
***************************************************************************/

#include <stddef.h>
#include <stdint.h>

#include "../../internals/e_acsl_debug.h"
#include "../../internals/e_acsl_malloc.h"
#include "../../internals/e_acsl_private_assert.h"
#include "../../instrumentation_model/e_acsl_temporal.h"
#include "../../numerical_model/e_acsl_floating_point.h"
#include "../internals/e_acsl_safe_locations.h"
#include "e_acsl_segment_tracking.h"
#include "e_acsl_shadow_layout.h"

#include "../internals/e_acsl_timestamp_retrieval.h"
#include "../e_acsl_observation_model.h"

void * eacsl_store_block(void *ptr, size_t size) {
  /* Only stack-global memory blocks are recorded explicitly via this function.
     Heap blocks should be tracked internally using memory allocation functions
     such as malloc or calloc. */
  shadow_alloca(ptr, size);
  return ptr;
}

void eacsl_delete_block(void *ptr) {
  /* Block deletion should be performed on stack/global addresses only,
   * heap blocks should be deallocated manually via free/cfree/realloc. */
  shadow_freea(ptr);
}

void * eacsl_store_block_duplicate(void *ptr, size_t size) {
  if (allocated((uintptr_t)ptr, size, (uintptr_t)ptr))
    eacsl_delete_block(ptr);
  shadow_alloca(ptr, size);
  return ptr;
}

/*! \brief Initialize a chunk of memory given by its start address (`addr`)
 * and byte length (`n`). */
void eacsl_initialize(void *ptr, size_t n) {
  TRY_SEGMENT(
    (uintptr_t)ptr,
    initialize_heap_region((uintptr_t)ptr, n),
    initialize_static_region((uintptr_t)ptr, n)
  )
}

void eacsl_full_init(void *ptr) {
  eacsl_initialize(ptr, _block_length(ptr));
}

void eacsl_mark_readonly(void *ptr) {
  mark_readonly_region((uintptr_t)ptr, _block_length(ptr));
}

/* ********************** */
/* E-ACSL annotations {{{ */
/* ********************** */

int eacsl_valid(void *ptr, size_t size, void *ptr_base, void *addrof_base) {
  return
    size == 0
    || (
    allocated((uintptr_t)ptr, size, (uintptr_t)ptr_base)
    && !readonly(ptr)
#ifdef E_ACSL_TEMPORAL
    && temporal_valid(ptr_base, addrof_base)
#endif
    );
}

int eacsl_valid_read(void *ptr, size_t size, void *ptr_base, void *addrof_base) {
  return
    size == 0
    || (
    allocated((uintptr_t)ptr, size, (uintptr_t)ptr_base)
#ifdef E_ACSL_TEMPORAL
    && temporal_valid(ptr_base, addrof_base)
#endif
    );
}

/*! NB: The implementation for this function can also be specified via
   \p _base_addr macro that will eventually call ::TRY_SEGMENT. The following
   implementation is preferred for performance reasons. */
void * eacsl_base_addr(void *ptr) {
  TRY_SEGMENT(ptr,
    return (void*)heap_info((uintptr_t)ptr, 'B'),
    return (void*)static_info((uintptr_t)ptr, 'B'));
  return NULL;
}

/*! NB: Implementation of the following function can also be specified
   via \p _block_length macro. A more direct approach via ::TRY_SEGMENT
   is preferred for performance reasons. */
size_t eacsl_block_length(void *ptr) {
  TRY_SEGMENT(ptr,
    return heap_info((uintptr_t)ptr, 'L'),
    return static_info((uintptr_t)ptr, 'L'))
  return 0;
}

size_t eacsl_offset(void *ptr) {
  TRY_SEGMENT(ptr,
    return heap_info((uintptr_t)ptr, 'O'),
    return static_info((uintptr_t)ptr, 'O'));
  return 0;
}

int eacsl_initialized(void *ptr, size_t size) {
  uintptr_t addr = (uintptr_t)ptr;
  TRY_SEGMENT_WEAK(addr,
    return heap_initialized(addr, size),
    return static_initialized(addr, size));
  return 0;
}
/* }}} */

/* Track program arguments (ARGC/ARGV) {{{ */

/* POSIX-compliant array of character pointers to the environment strings. */
extern char ** environ;

static void argv_alloca(int *argc_ref,  char *** argv_ref) {
  /* Track a top-level containers */
  shadow_alloca((void*)argc_ref, sizeof(int));
  shadow_alloca((void*)argv_ref, sizeof(char**));
  int argc = *argc_ref;
  char** argv = *argv_ref;
  /* Track argv */
  size_t argvlen = (argc + 1)*sizeof(char*);
  shadow_alloca(argv, argvlen);
  initialize_static_region((uintptr_t)argv, (argc + 1)*sizeof(char*));

  /* Track argument strings */
  while (*argv) {
    /* Account for `\0` when copying C strings */
    size_t arglen = strlen(*argv) + 1;
#ifdef E_ACSL_TEMPORAL
    /* Move `argv` strings to heap. This is because they are allocated
       sparcely and there is no way to align they (if they are small), so there
       may no be sufficient space for storing origin time stamps.
       Generally speaking, this is not the best of ideas, more of a temporary
       fix to avoid various range comparisons. A different approach is
       therefore more than welcome. */
    *argv = shadow_copy(*argv, arglen, 1);
    /* TODO: These heap allocations are never freed in fact. Not super
       important, but for completeness purposes it may be feasible to define
       a buffer of implicitly allocated memory locations which need to be
       freed before a program exists. */
#else
    shadow_alloca(*argv, arglen);
    initialize_static_region((uintptr_t)*argv, arglen);
#endif
    argv++;
  }
#ifdef E_ACSL_TEMPORAL
  /* Fill temporal shadow */
  int i;
  argv = *argv_ref;
  eacsl_temporal_store_nblock(argv_ref, *argv_ref);
  for (i = 0; i < argc; i++)
    eacsl_temporal_store_nblock(argv + i, *(argv+i));
#endif

  while (*environ) {
    size_t envlen = strlen(*environ) + 1;
#ifdef E_ACSL_TEMPORAL
    *environ = shadow_copy(*environ, envlen, 1);
#else
    shadow_alloca(*environ, envlen);
    initialize_static_region((uintptr_t)*environ, envlen);
#endif
    environ++;
  }
}
/* }}} */

/* Program initialization {{{ */
extern int main(void);

void mspaces_init() {
  /* [already_run] avoids reentrancy issue (see Gitlab issue #83),
     e.g. in presence of a GCC's constructors that invokes malloc possibly
     several times before calling main. */
  static char already_run = 0;
  if (! already_run) {
    describe_run();
    eacsl_make_memory_spaces(64*MB, get_heap_size());
    /* Allocate and log shadow memory layout of the execution.
       Case of the heap, globals and tls. */
    init_shadow_layout_heap_global_tls();
    already_run = 1;
  }
}

void eacsl_memory_init(int *argc_ref, char *** argv_ref, size_t ptr_size) {
  /* [already_run] avoids reentrancy issue (see Gitlab issue #83),
     e.g. in presence of a recursive call to 'main' */
  static char already_run = 0;
  if (! already_run) {
    mspaces_init();
    /* Verify that the given size of a pointer matches the one in the present
       architecture. This is a guard against Frama-C instrumentations using
       architectures different to the given one. */
    arch_assert(ptr_size);
    /* Initialize report file with debug logs (only in debug mode). */
    initialize_report_file(argc_ref, argv_ref);
    /* Lift stack limit to account for extra stack memory overhead.  */
    increase_stack_limit(get_stack_size()*2);
    /* Allocate and log shadow memory layout of the execution. Case of stack. */
    init_shadow_layout_stack(argc_ref, argv_ref);
    //DEBUG_PRINT_LAYOUT;
    /* Make sure the layout holds */
    DVALIDATE_SHADOW_LAYOUT;
    /* Track program arguments. */
    if (argc_ref && argv_ref)
      argv_alloca(argc_ref, argv_ref);
    /* Track main function */
    shadow_alloca(&main, sizeof(&main));
    initialize_static_region((uintptr_t)&main, sizeof(&main));
    /* Tracking safe locations */
    collect_safe_locations();
    int i;
    for (i = 0; i < get_safe_locations_count(); i++) {
    memory_location * loc = get_safe_location(i);
      void *addr = (void*)loc->address;
      uintptr_t len = loc->length;
      shadow_alloca(addr, len);
      if (loc->is_initialized)
        eacsl_initialize(addr, len);
    }
    init_infinity_values();
    already_run = 1;
  }
}

void eacsl_memory_clean(void) {
  clean_shadow_layout();
  report_heap_leaks();
}
/* }}} */
