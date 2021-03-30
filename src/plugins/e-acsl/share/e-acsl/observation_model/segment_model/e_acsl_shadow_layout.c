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

#include <errno.h>
#include <stddef.h>

#include "../../internals/e_acsl_private_assert.h"
#include "../../internals/e_acsl_malloc.h"

#include "e_acsl_shadow_layout.h"

#if E_ACSL_OS_IS_LINUX

#include <sys/resource.h>

/** Program stack information {{{ */

/* Symbols exported by the linker script */

/*!\brief The first address past the end of the text segment. */
extern char etext;
/*!\brief The first address past the end of the initialized data segment. */
extern char edata;
/*!\brief The first address past the end of the uninitialized data segment. */
extern char end;
/*!\brief The first address of a program. */
extern char __executable_start;

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
    } else {
      stacksz = rl.rlim_cur;
    }
  } else {
    private_abort("getrlimit: %s \n", strerror(errno));
  }
  return (size_t)stacksz;
}

size_t get_stack_size() {
  struct rlimit rlim;
  private_assert(!getrlimit(RLIMIT_STACK, &rlim),
    "Cannot detect program's stack size", NULL);
  return rlim.rlim_cur;
}


extern char ** environ;

/*! \brief Return the greatest (known) address on a program's stack.
 * This function presently determines the address using the address of the
 * last string in `environ`. That is, it assumes that argc and argv are
 * stored below environ, which holds for GCC or Clang and Glibc but is not
 * necessarily true for some other compilers/libraries. */
static uintptr_t get_stack_start(int *argc_ref,  char *** argv_ref) {
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

  // Check that the assumption that argc and argv are stored below environ in
  // the stack holds
  DVASSERT(stack_start <= (uintptr_t)argc_ref
           && (uintptr_t)argc_ref <= stack_end,
           "Assumption that argc is stored below environ is not verified.\n\
           \tStack: [%a - %a]\n\t&argc: %a",
           stack_start, stack_end, argc_ref);
  DVASSERT(stack_start <= (uintptr_t)argv_ref
           && (uintptr_t)argv_ref <= stack_end,
           "Assumption that argv is stored below environ is not verified.\n\
           \tStack: [%a - %a]\n\t&argc: %a",
           stack_start, stack_end, argc_ref);

  return stack_start;
}
/* }}} */

/** Program global information {{{ */
/*! \brief Return the start address of a segment holding globals (generally
 * BSS and Data segments). */
static uintptr_t get_global_start() {
  return (uintptr_t)&__executable_start;
}

/*! \brief Return byte-size of global segment */
static size_t get_global_size() {
  return ((uintptr_t)&end - get_global_start());
}
/** }}} */

/** Thread-local storage information {{{ */

/*! Thread-local storage (TLS) keeps track of copies of per-thread variables.
 * Even though at the present stage, E-ACSL's RTL is not thread-safe, some
 * of the variables (for instance ::errno) are allocated there. In X86, TLS
 * is typically located somewhere below the program's stack but above mmap
 * areas. TLS is typically separated into two sections: .tdata and .tbss.
 * Similar to globals using .data and .bss, .tdata keeps track of initialized
 * thread-local variables, while .tbss holds uninitialized ones.
 *
 * Start and end addresses of TLS are obtained by taking addresses of
 * initialized and uninitialized variables in TLS (::id_tdata and ::id_tss)
 * and adding fixed amount of shadow space around them. Visually it looks
 * as follows:
 *
 *   end TLS address (&id_tdata + TLS_SHADOW_SIZE/2)
 *   id_tdata address
 *   ...
 *   id_tbss address
 *   start TLS address (&id_bss - TLS_SHADOW_SIZE/2)
 *
 * HOWEVER problems can occur if PGM_TLS_SIZE is too big:
 * see get_tls_start for details.
 */

/*! \brief Return byte-size of the TLS segment */
inline static size_t get_tls_size() {
  return PGM_TLS_SIZE;
}

static __thread int id_tdata = 1;
static __thread int id_tbss;

/*! \brief Return start address of a program's TLS */
static uintptr_t get_tls_start() {
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

/* }}} */

/** Memory partitions {{{ */
static void init_shadow_layout_global() {
  memory_partition *pglobal = &mem_layout.global;
  set_application_segment(&pglobal->application, get_global_start(),
    get_global_size(), "global", NULL);
  set_shadow_segment(&pglobal->primary, &pglobal->application, 1, "global_primary");
  set_shadow_segment(&pglobal->secondary, &pglobal->application, 1, "global_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pglobal->temporal_primary, &pglobal->application, 1, "temporal_global_primary");
  set_shadow_segment(&pglobal->temporal_secondary, &pglobal->application, 1, "temporal_global_secondary");
#endif
}

static void init_shadow_layout_tls() {
  memory_partition *ptls = &mem_layout.tls;
  set_application_segment(&ptls->application, get_tls_start(),
    get_tls_size(), "tls", NULL);
  set_shadow_segment(&ptls->primary, &ptls->application, 1, "tls_primary");
  set_shadow_segment(&ptls->secondary, &ptls->application, 1, "tls_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&ptls->temporal_primary, &ptls->application, 1, "temporal_tls_primary");
  set_shadow_segment(&ptls->temporal_secondary, &ptls->application, 1, "temporal_tls_secondary");
#endif
}

static void init_shadow_layout_stack(int *argc_ref, char ***argv_ref) {
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
}
/** }}} */
#elif E_ACSL_OS_IS_WINDOWS

#include <processthreadsapi.h>
#include <windows.h>
#include <dbghelp.h>


/** Program segment informations {{{ */
typedef struct mem_loc_info {
  uintptr_t start;
  size_t size;
} mem_loc_info_t;

static mem_loc_info_t get_section_info(HANDLE hModule, const char * section_name) {
  // Get the location of the module's IMAGE_NT_HEADERS structure
  IMAGE_NT_HEADERS *pNtHdr = ImageNtHeader(hModule);

  // Section table immediately follows the IMAGE_NT_HEADERS
  IMAGE_SECTION_HEADER *pSectionHdr = (IMAGE_SECTION_HEADER *)(pNtHdr + 1);

  const char* imageBase = (const char*)hModule;
  size_t scnNameSize = sizeof(pSectionHdr->Name);
  char scnName[scnNameSize + 1];
  // Enforce nul-termination for scn names that are the whole length of
  // pSectionHdr->Name[]
  scnName[scnNameSize] = '\0';

  mem_loc_info_t res = { .start = 0, .size = 0 };

  for (int scn = 0; scn < pNtHdr->FileHeader.NumberOfSections; ++scn, ++pSectionHdr) {
    // Note: pSectionHdr->Name[] is 8-byte long. If the scn name is 8-byte
    // long, ->Name[] will not be nul-terminated. For this reason, copy it to a
    // local buffer that is nul-terminated to be sure we only print the real scn
    // name, and no extra garbage beyond it.
    strncpy(scnName, (const char*)pSectionHdr->Name, scnNameSize);

    if (strcmp(scnName, section_name) == 0) {
      res.start = (uintptr_t)imageBase + pSectionHdr->VirtualAddress;
      res.size = pSectionHdr->Misc.VirtualSize;
      break;
    }
  }

  return res;
}
/** }}} */

/** Program stack information {{{ */
static mem_loc_info_t get_stack_mem_loc_info() {
  ULONG_PTR low;
  ULONG_PTR high;
  GetCurrentThreadStackLimits(&low, &high);
  return (mem_loc_info_t) {
    .start = low,
    .size = high - low + 1
  };
}

size_t increase_stack_limit(const size_t size) {
  size_t actual_size = get_stack_size();
  if (actual_size < size) {
    DLOG("Increasing stack size at runtime is unsupported on Windows.\n\
      \t   Actual stack size: %lu\n\
      \tRequested stack size: %lu\n",
      actual_size, size);
  }
  return actual_size;
}

size_t get_stack_size() {
  return get_stack_mem_loc_info().size;
}
/** }}} */

/** Memory partitions {{{ */
static void init_shadow_layout_stack(int *argc_ref, char ***argv_ref) {
  memory_partition *pstack = &mem_layout.stack;
  mem_loc_info_t stack_loc_info = get_stack_mem_loc_info();
  set_application_segment(&pstack->application, stack_loc_info.start,
    stack_loc_info.size, "stack", NULL);
  set_shadow_segment(&pstack->primary, &pstack->application, 1, "stack_primary");
  set_shadow_segment(&pstack->secondary, &pstack->application, 1, "stack_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pstack->temporal_primary, &pstack->application, 1, "temporal_stack_primary");
  set_shadow_segment(&pstack->temporal_secondary, &pstack->application, 1, "temporal_stack_secondary");
#endif
}

static void init_shadow_layout_text(HMODULE module) {
  // Retrieve mem loc info for the text section
  mem_loc_info_t text = get_section_info(module, ".text");

  memory_partition *ptext = &mem_layout.text;
  set_application_segment(&ptext->application, text.start,
    text.size, "text", NULL);
  set_shadow_segment(&ptext->primary, &ptext->application, 1, "text_primary");
  set_shadow_segment(&ptext->secondary, &ptext->application, 1, "text_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&ptext->temporal_primary, &ptext->application, 1, "temporal_text_primary");
  set_shadow_segment(&ptext->temporal_secondary, &ptext->application, 1, "temporal_text_secondary");
#endif
}

static void init_shadow_layout_bss(HMODULE module) {
  // Retrieve mem loc info for the uninidialized data segment
  mem_loc_info_t bss = get_section_info(module, ".bss");

  memory_partition *pbss = &mem_layout.bss;
  set_application_segment(&pbss->application, bss.start, bss.size, "bss", NULL);
  set_shadow_segment(&pbss->primary, &pbss->application, 1, "bss_primary");
  set_shadow_segment(&pbss->secondary, &pbss->application, 1, "bss_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pbss->temporal_primary, &pbss->application, 1, "temporal_bss_primary");
  set_shadow_segment(&pbss->temporal_secondary, &pbss->application, 1, "temporal_bss_secondary");
#endif
}

static void init_shadow_layout_data(HMODULE module) {
  // Retrieve mem loc info for the initialized data segment
  mem_loc_info_t data = get_section_info(module, ".data");

  memory_partition *pdata = &mem_layout.data;
  set_application_segment(&pdata->application, data.start, data.size, "data", NULL);
  set_shadow_segment(&pdata->primary, &pdata->application, 1, "data_primary");
  set_shadow_segment(&pdata->secondary, &pdata->application, 1, "data_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pdata->temporal_primary, &pdata->application, 1, "temporal_data_primary");
  set_shadow_segment(&pdata->temporal_secondary, &pdata->application, 1, "temporal_data_secondary");
#endif
}

static void init_shadow_layout_idata(HMODULE module) {
  // Retrieve mem loc info for the initialized data segment
  mem_loc_info_t idata = get_section_info(module, ".idata");

  memory_partition *pidata = &mem_layout.idata;
  set_application_segment(&pidata->application, idata.start, idata.size, "idata", NULL);
  set_shadow_segment(&pidata->primary, &pidata->application, 1, "idata_primary");
  set_shadow_segment(&pidata->secondary, &pidata->application, 1, "idata_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pidata->temporal_primary, &pidata->application, 1, "temporal_idata_primary");
  set_shadow_segment(&pidata->temporal_secondary, &pidata->application, 1, "temporal_idata_secondary");
#endif
}

static void init_shadow_layout_rdata(HMODULE module) {
  // Retrieve mem loc info for the initialized data segment
  mem_loc_info_t rdata = get_section_info(module, ".rdata");

  memory_partition *prdata = &mem_layout.rdata;
  set_application_segment(&prdata->application, rdata.start, rdata.size, "rdata", NULL);
  set_shadow_segment(&prdata->primary, &prdata->application, 1, "rdata_primary");
  set_shadow_segment(&prdata->secondary, &prdata->application, 1, "rdata_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&prdata->temporal_primary, &prdata->application, 1, "temporal_rdata_primary");
  set_shadow_segment(&prdata->temporal_secondary, &prdata->application, 1, "temporal_rdata_secondary");
#endif
}
/** }}} */
#endif

/** Program heap information {{{ */
static uintptr_t get_heap_start() {
  return mem_spaces.heap_start;
}

size_t get_heap_size() {
  return PGM_HEAP_SIZE;
}

static size_t get_heap_init_size() {
  return get_heap_size()/8;
}

static void init_shadow_layout_heap() {
  memory_partition *pheap = &mem_layout.heap;
  set_application_segment(&pheap->application, get_heap_start(),
    get_heap_size(), "heap", mem_spaces.heap_mspace);
  set_shadow_segment(&pheap->primary, &pheap->application, 1, "heap_primary");
  set_shadow_segment(&pheap->secondary, &pheap->application, 8, "heap_secondary");
#ifdef E_ACSL_TEMPORAL
  set_shadow_segment(&pheap->temporal_primary, &pheap->application, 1, "temporal_heap_primary");
  set_shadow_segment(&pheap->temporal_secondary, &pheap->application, 1, "temporal_heap_secondary");
#endif
}
/** }}} */

/** Shadow Layout {{{ */

void set_application_segment(memory_segment *seg, uintptr_t start,
    size_t size, const char *name, mspace msp) {
  seg->name = name;
  seg->start = start;
  seg->size = size;
  seg->end = seg->start + seg->size - 1;
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
  seg->mspace = eacsl_create_mspace(seg->size + SHADOW_SEGMENT_PADDING, 0);
  seg->start = (uintptr_t)eacsl_mspace_malloc(seg->mspace,1);
  seg->end = seg->start + seg->size - 1;
  seg->shadow_offset = parent->start - seg->start;
}

void init_shadow_layout_pre_main() {
  init_shadow_layout_heap();

#if E_ACSL_OS_IS_LINUX
  init_shadow_layout_global();
  init_shadow_layout_tls();
#elif E_ACSL_OS_IS_WINDOWS
  HANDLE module = GetModuleHandle(NULL);
  init_shadow_layout_text(module);
  init_shadow_layout_bss(module);
  init_shadow_layout_data(module);
  init_shadow_layout_idata(module);
  init_shadow_layout_rdata(module);
#endif

  mem_layout.is_initialized_pre_main = 1;
}

void init_shadow_layout_main(int *argc_ref, char *** argv_ref) {
  init_shadow_layout_stack(argc_ref, argv_ref);

  mem_layout.is_initialized_main = 1;
}

void clean_shadow_layout() {
  if (mem_layout.is_initialized_pre_main && mem_layout.is_initialized_main) {
    int i;
    for (i = 0; i < sizeof(mem_partitions)/sizeof(memory_partition*); i++) {
      if (mem_partitions[i]->primary.mspace)
        eacsl_destroy_mspace(mem_partitions[i]->primary.mspace);
      if (mem_partitions[i]->secondary.mspace)
        eacsl_destroy_mspace(mem_partitions[i]->secondary.mspace);
    }
  }
}
/** }}} */
