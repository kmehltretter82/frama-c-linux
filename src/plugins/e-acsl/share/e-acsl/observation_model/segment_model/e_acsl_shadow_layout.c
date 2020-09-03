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

#include <sys/resource.h>
#include <errno.h>
#include <stddef.h>

#include "../../internals/e_acsl_private_assert.h"
#include "../../internals/e_acsl_malloc.h"

#include "e_acsl_shadow_layout.h"

/** Program stack information {{{ */

size_t increase_stack_limit(const size_t size) {
  rlim_t stacksz = (rlim_t)size;
  struct rlimit rl;
  int result = getrlimit(RLIMIT_STACK, &rl);
  if (result == 0) {
    if (rl.rlim_cur < stacksz) {
      if (stacksz>rl.rlim_max) stacksz = rl.rlim_max;
      rl.rlim_cur = stacksz;
      result = setrlimit(RLIMIT_STACK, &rl);
      if (result != 0) {
        private_abort("setrlimit: %s \n", strerror(errno));
      }
    }
  } else {
    private_abort("getrlimit: %s \n", strerror(errno));
  }
  return (size_t)stacksz;
}

size_t get_default_stack_size() {
  struct rlimit rlim;
  private_assert(!getrlimit(RLIMIT_STACK, &rlim),
    "Cannot detect program's stack size", NULL);
  return rlim.rlim_cur;
}

size_t get_stack_size() {
#ifndef E_ACSL_STACK_SIZE
  return get_default_stack_size();
#else
  return increase_stack_limit(E_ACSL_STACK_SIZE*MB);
#endif
}

uintptr_t get_stack_start(int *argc_ref,  char *** argv_ref) {
  char **env = environ;
  while (env[1])
    env++;
  uintptr_t addr = (uintptr_t)*env + strlen(*env);

  /* When returning the end stack address we need to make sure that
   * ::ULONG_BITS past that address are actually writeable. This is
   * to be able to set initialization and read-only bits ::ULONG_BITS
   * at a time. If not respected, this may cause a segfault in
   * ::argv_alloca. */
  uintptr_t stack_end = addr + ULONG_BITS;
  uintptr_t stack_start = stack_end - get_stack_size();
  return stack_start;
}
/* }}} */

/** Program heap information {{{ */
uintptr_t get_heap_start() {
  return mem_spaces.heap_start;
}

size_t get_heap_size() {
  return PGM_HEAP_SIZE;
}

size_t get_heap_init_size() {
  return get_heap_size()/8;
}

uintptr_t get_global_start() {
  return (uintptr_t)&__executable_start;
}

size_t get_global_size() {
  return ((uintptr_t)&end - get_global_start());
}
/** }}} */

/** Shadow Layout {{{ */

void set_application_segment(memory_segment *seg, uintptr_t start,
    size_t size, const char *name, mspace msp) {
  seg->name = name;
  seg->start = start;
  seg->size = size;
  seg->end = seg->start + seg->size;
  seg->mspace = msp;
  seg->parent = NULL;
  seg->shadow_ratio = 0;
  seg->shadow_offset = 0;
}

void set_shadow_segment(memory_segment *seg, memory_segment *parent,
    size_t ratio, const char *name) {
  seg->parent = parent;
  seg->name = name;
  seg->shadow_ratio = ratio;
  seg->size = parent->size/seg->shadow_ratio;
  seg->mspace = create_mspace(seg->size + SHADOW_SEGMENT_PADDING, 0);
  seg->start = (uintptr_t)mspace_malloc(seg->mspace,1);
  seg->end = seg->start + seg->size;
  seg->shadow_offset = parent->start - seg->start;
}

void init_shadow_layout_stack(int *argc_ref, char ***argv_ref) {
  memory_partition *pstack = &mem_layout.stack;
  set_application_segment(&pstack->application, get_stack_start(argc_ref, argv_ref),
    get_stack_size(), "stack", NULL);
  /* Changes of the ratio in the following will require changes in get_tls_start */
  set_shadow_segment(&pstack->primary, &pstack->application, 1, "stack_primary");
  set_shadow_segment(&pstack->secondary, &pstack->application, 1, "stack_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pstack->temporal_primary, &pstack->application, 1, "temporal_stack_primary");
  set_shadow_segment(&pstack->temporal_secondary, &pstack->application, 1, "temporal_stack_secondary");
#endif

  mem_layout.is_initialized = 1;
}

uintptr_t get_tls_start() {
  size_t tls_size = get_tls_size();
  uintptr_t data = (uintptr_t)&id_tdata,
            bss = (uintptr_t)&id_tbss;
  /* It could happen that the shadow allocated before bss is too big.
    Indeed allocating PGM_TLS_SIZE/2 could cause an overlap with the other
    shadow segments AND heap.application (in case the latter is too big too).
    In such cases, take the smallest available address (the max used +1). */
  uintptr_t tls_start_half = (data > bss ? bss : data) - tls_size/2;
  memory_partition pheap = mem_layout.heap,
                   pglobal = mem_layout.global;
  uintptr_t max_shadow = pheap.primary.end;
  max_shadow = pheap.secondary.end > max_shadow ?
    pheap.secondary.end : max_shadow;
  max_shadow = pglobal.primary.end > max_shadow ?
    pglobal.primary.end : max_shadow;
  max_shadow = pglobal.secondary.end > max_shadow ?
    pglobal.secondary.end : max_shadow;
  max_shadow = pheap.application.end > max_shadow ?
    pheap.application.end : max_shadow;
  /* Shadow stacks are not yet allocated at his point since
     init_shadow_layout_stack is called after
     init_shadow_layout_heap_global_tls (for reasons related to memory
     initialization in presence of things like GCC constructors).
     We must leave sufficient space for them. */
  max_shadow = max_shadow +
    2*get_stack_size() + /* One for primary, one for secondary.
                            If ratio is changed in init_shadow_layout_stack
                            then update required here.
                            TODO: if stack too big ==> problem */
    1;
  return tls_start_half > max_shadow ? tls_start_half : max_shadow;
}

void init_shadow_layout_heap_global_tls() {
  memory_partition *pheap = &mem_layout.heap;
  set_application_segment(&pheap->application, get_heap_start(),
    get_heap_size(), "heap", mem_spaces.heap_mspace);
  set_shadow_segment(&pheap->primary, &pheap->application, 1, "heap_primary");
  set_shadow_segment(&pheap->secondary, &pheap->application, 8, "heap_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pheap->temporal_primary, &pheap->application, 1, "temporal_heap_primary");
  set_shadow_segment(&pheap->temporal_secondary, &pheap->application, 1, "temporal_heap_secondary");
#endif

  memory_partition *pglobal = &mem_layout.global;
  set_application_segment(&pglobal->application, get_global_start(),
    get_global_size(), "global", NULL);
  set_shadow_segment(&pglobal->primary, &pglobal->application, 1, "global_primary");
  set_shadow_segment(&pglobal->secondary, &pglobal->application, 1, "global_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pglobal->temporal_primary, &pglobal->application, 1, "temporal_global_primary");
  set_shadow_segment(&pglobal->temporal_secondary, &pglobal->application, 1, "temporal_global_secondary");
#endif

  memory_partition *ptls = &mem_layout.tls;
  set_application_segment(&ptls->application, get_tls_start(),
    get_tls_size(), "tls", NULL);
  set_shadow_segment(&ptls->primary, &ptls->application, 1, "tls_primary");
  set_shadow_segment(&ptls->secondary, &ptls->application, 1, "tls_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&ptls->temporal_primary, &ptls->application, 1, "temporal_tls_primary");
  set_shadow_segment(&ptls->temporal_secondary, &ptls->application, 1, "temporal_tls_secondary");
#endif

  mem_layout.is_initialized = 1;
}

void clean_shadow_layout() {
  if (mem_layout.is_initialized) {
    int i;
    for (i = 0; i < sizeof(mem_partitions)/sizeof(memory_partition*); i++) {
      if (mem_partitions[i]->primary.mspace)
        destroy_mspace(mem_partitions[i]->primary.mspace);
      if (mem_partitions[i]->secondary.mspace)
        destroy_mspace(mem_partitions[i]->secondary.mspace);
    }
  }
}
/** }}} */
