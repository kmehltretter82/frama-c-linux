/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2015                                               */
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
 * \file  e_acsl_shadow_layout.h
 * \brief Setup for memory tracking using shadowing
***************************************************************************/

/*! \brief The first address past the end of BSS segment */
extern char end;

/* \cond */
void *sbrk(intptr_t increment);
char *strerror(int errnum);

/* MAP_ANONYMOUS is a mmap flag indicating that the contents of allocated blocks
 * should be nullified. Set value from <bits/mman-linux.h>, if MAP_ANONYMOUS is
 * undefined */
#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS 0x20
#endif
/* \endcond */

/* Block size units in bytes */
#define KB (1024) //!< Bytes in a kilobyte
#define MB (1024*KB) //!< Bytes in a megabyte
#define GB (1024*MB) //!< Bytes in a gigabyte
#define KB_SZ(_s) (_s/KB) //!< Convert bytes to kilobytes
#define MB_SZ(_s) (_s/MB) //!< Convert bytes to megabytes
#define GB_SZ(_s) (_s/GB) //!< Convert bytes to gigabytes

/*! \brief Pointer size (in bytes) for a given system */
#define PTR_SZ sizeof(uintptr_t)

/*! \brief Bit and byte sizes of a unsigned long type, i.e., the largest
 * integer type that can be used with bit-level operators.
 * NB: Some architectures allow 128-bit (i.e., 16 byte integers),
 * but the availability of such integer types is implementation specific. */
#define ULONG_BYTES 8
#define ULONG_BITS 64

/** Hardcoded sizes of tracked program segments {{{ */
/*! \brief Size of the heap segment */
#define PGM_HEAP_SIZE (256 * MB)

/*! \brief Size of the TLS segment */
#define PGM_TLS_SIZE (8 * MB)
/* }}} */

/** Thread-local storage information {{{ */

/*! Thread-local storage (TLS) keeps track of copies of per-thread variables.
 * Even though at the present stage RTL of E-ACSL is not thread-safe, some
 * of the variables (for instance ::errno) are allocated there. In X86 TLS
 * is typically located somewhere below the program's stack but above mmap
 * areas. TLS is typically separated into two sections: .tdata and .tbss.
 * Similar to globals using .data and .bss, .tdata keeps track of initialized
 * thread-local variables, while .tbss holds uninitialized ones.
 *
 * Start and end addresses of TLS are obtained by taking addresses of
 * initialized and initialized variables in TLS (::id_tdata and ::id_tss)
 * and adding fixed amount of shadow space around them. Visually it looks
 * as follows:
 *
 *   end TLS address (&id_tdata + TLS_SHADOW_SIZE/2)
 *   id_tdata address
 *   ...
 *   id_tbss address
 *   start TLS address (&id_bss - TLS_SHADOW_SIZE/2)
 */

/*! Get byte-size of TLS segment */
static size_t get_tls_size() {
  return PGM_TLS_SIZE;
}

static __thread int id_tdata = 1;
static __thread int id_tbss;

/*! Set TLS size and its end and start addresses. */
static uintptr_t get_tls_start() {
  size_t tls_size = get_tls_size();
  uintptr_t data = (uintptr_t)&id_tdata,
            bss = (uintptr_t)&id_tbss;
  return ((data > bss ? bss  : data) - tls_size/2);
}

/* }}} */

/** Program stack information {{{ */
extern char ** environ;

/*! \brief Get the stack size (in bytes) as used by the program. The return
 * value is the soft stack limit, i.e., it can be programmatically increased
 * at runtime */
static size_t get_stack_size() {
  struct rlimit rlim;
  assert(!getrlimit(RLIMIT_STACK, &rlim));
  return rlim.rlim_cur;
}

/*! \brief Return greatest (known) address on a program's stack.
 * This function presently determines the address using the address of the
 * last string in `environ`. That is, it assumes that argc and argv are
 * stored below environ, which holds for GCC/GLIBC but is not necessarily
 * true. In general, a reliable way of detecting the upper bound of a stack
 * segment is needed. */
static uintptr_t get_stack_start(int *argc_ref,  char *** argv_ref) {
  char **env = environ;
  while (env[1])
    env++;
  uintptr_t addr = (uintptr_t)*env + strlen(*env);

  /* When returning the end stack addess we need to make sure that
   * ::ULONG_BITS past that address are actually writable. This is
   * to be able to set initialization and read-only bits ::ULONG_BITS
   * at a time. If not respected, this may cause a segfault in
   * ::argv_alloca. */
  uintptr_t stack_end = addr + ULONG_BITS;
  uintptr_t stack_start = stack_end - get_stack_size();
  return stack_start;
}

/*! \brief Set a new stack limit
 * \param size - new stack size in bytes */
static void increase_stack_limit(const size_t size) {
  const rlim_t stacksz = (rlim_t)size;
  struct rlimit rl;
  int result = getrlimit(RLIMIT_STACK, &rl);
  if (result == 0) {
    if (rl.rlim_cur < stacksz) {
      rl.rlim_cur = stacksz;
      result = setrlimit(RLIMIT_STACK, &rl);
      if (result != 0) {
        vabort("setrlimit returned result = %d\n", result);
      }
    }
  }
}
/* }}} */

/** Program heap information {{{ */
static uintptr_t get_heap_start() {
  return (uintptr_t)sbrk(0);
}

static size_t get_heap_size() {
  return PGM_HEAP_SIZE;
}
/** }}} */

/** Program global information {{{ */
static uintptr_t get_global_start() {
  return (uintptr_t)(PTR_SZ*2);
}

/*! \brief Get byte-size of global segment */
static size_t get_global_size() {
/* In all likelihood it is reasonably safe to assume that first
  * 2x*pointer-size bytes of the memory space will not be used. */
  return ((uintptr_t)&end - get_global_start());
}
/** }}} */

/** MMAP allocation {{{ */
/*! \brief Allocate a memory block of `size` bytes with `mmap` and return a
 * pointer to its base address. Since this function is used to set-up shadowing
 * the program is aborted if `mmap` fails to allocate a new memory block. */
static void *do_mmap(size_t size) {
  void *res = mmap(0, size, PROT_READ|PROT_WRITE,
    MAP_ANONYMOUS|MAP_PRIVATE, -1, (size_t)0);
  if (res == MAP_FAILED)
      vabort("mmap error: %s\n", strerror(errno));
  else
      memset(res, 0, size);
  return res;
}
/* }}} */

/** Shadow Offset {{{ */
/*! Compute shadow offset between the start address of a shadow area and a
 * start address of a segment */
static uintptr_t shadow_offset(void *shadow, uintptr_t start_addr) {
  uintptr_t start_shadow = (uintptr_t)shadow;
  return (start_shadow > start_addr) ?
    start_shadow - start_addr : start_addr - start_shadow;
}
/* }}} */

/** Program Layout {{{ */
/*****************************************************************************
 * Memory Layout *************************************************************
 *****************************************************************************
  ----------------------------------------> Max address
  Kernel Space
  ---------------------------------------->
  Non-canonical address space (only in 64-bit)
  ---------------------------------------->
  Environment variables [ GLIBC extension ]
 ----------------------------------------->
  Program arguments [ argc, argv ]
 -----------------------------------------> Stack End
  Stack [ Grows downwards ]
 ----------------------------------------->
  Thread-local storage (TLS) [ TDATA and TBSS ]
 ----------------------------------------->
  Shadow memory [ Heap, Stack, Global, TLS ]
 ----------------------------------------->
  Object mappings
 ----------------------------------------->
 ----------------------------------------->
  Heap [ Grows upwards^ ]
 -----------------------------------------> Heap Start [Initial Brk]
  BSS Segment  [ Uninitialised Globals ]
 ----------------------------------------->
  Data Segment [ Initialised Globals   ]
 ----------------------------------------->
  ROData [ Potentially ]
 ----------------------------------------->
  Text Segment [ Constants ]
 -----------------------------------------> NULL (0)
 *****************************************************************************
NOTE: Above memory layout scheme generally applies to Linux Kernel/gcc/glibc.
  It is also an approximation slanted towards 64-bit virtual process layout.
  In reality layouts may vary.

NOTE: With mmap allocations heap does not necessarily grows from program break
  upwards. Typically mmap will allocate memory somewhere closer to stack. This
  implementation, however, uses brk allocations, thus forcing stack to grow
  upwards from program break.
*/

/* Struct representing a memory segment along with information about its
 * shadow spaces. */
struct memory_segment {
  uintptr_t start; //!< Least address in application segment
  uintptr_t end; //!< Greatest address in application segment

  size_t shadow_size; //!< Byte-size of shadow area

  uintptr_t prim_start; //!< Least address in primary shadow
  uintptr_t prim_end; //!< Greatest address in primary shadow
  uintptr_t prim_offset; //!< Primary shadow offset

  uintptr_t sec_start; //!< Least address secondary shadow
  uintptr_t sec_end; //!< Greatest address secondary shadow
  uintptr_t sec_offset; //!< Secondary shadow offset

  int initialized; //! Notion on whether the layout is initialized
};

/*! \brief Full program memory layout. */
static struct memory_layout mem_layout;

struct memory_layout {
  struct memory_segment heap;
  struct memory_segment stack;
  struct memory_segment global;
  struct memory_segment tls;
  int initialized;
};

/*! \brief Set a given memory segment and its shadow spaces. */
static void set_shadow_segment(struct memory_segment *seg, uintptr_t start,
    uintptr_t size, int secondary) {
  seg->start = start;
  seg->end = seg->start + size - 1;
  seg->shadow_size = size;

  void *prim_shadow = do_mmap(seg->shadow_size);
  seg->prim_start = (uintptr_t)prim_shadow;
  seg->prim_end = seg->prim_start + seg->shadow_size - 1;
  seg->prim_offset = shadow_offset(prim_shadow, start);

  if (secondary) {
    void *sec_shadow = do_mmap(seg->shadow_size);
    seg->sec_start = (uintptr_t)sec_shadow;
    seg->sec_end = seg->sec_start + seg->shadow_size - 1;
    seg->sec_offset = shadow_offset(sec_shadow, seg->start);
  } else {
    seg->sec_start = seg->sec_end = seg->sec_offset = 0;
  }
}

/*! \brief Initialize memory layout, i.e., determine bounds of program segments,
 * allocate shadow memory spaces and compute offsets. This function populates
 * global struct ::mem_layout holding that information with data. */
static void init_memory_layout(int *argc_ref, char ***argv_ref) {
  DLOG("<<< Initialize heap shadow >>>\n");
  struct memory_segment *heap = &mem_layout.heap;
  set_shadow_segment(heap, get_heap_start(), get_heap_size(), 0);

  DLOG("<<< Initialize stack shadow >>>\n");
  struct memory_segment *stack = &mem_layout.stack;
  set_shadow_segment(stack, get_stack_start(argc_ref, argv_ref), get_stack_size(), 1);

  DLOG("<<< Initialize global shadow >>>\n");
  struct memory_segment *global = &mem_layout.global;
  set_shadow_segment(global, get_global_start(), get_global_size(), 1);

  DLOG("<<< Initialize TLS shadow >>>\n");
  struct memory_segment *tls = &mem_layout.tls;
  set_shadow_segment(tls, get_tls_start(), get_tls_size(), 1);

  mem_layout.initialized = 1;
}

/*! \brief Deallocate a shadow segment */
void clean_memory_segment(struct memory_segment *seg, int secondary) {
  munmap((void*)seg->prim_start, seg->shadow_size);
  if (secondary)
    munmap((void*)seg->sec_start, seg->shadow_size);
}

/*! \brief Deallocate shadow regions used by runtime analysis */
static void clean_memory_layout() {
  DLOG("<<< Clean shadow layout >>>\n");
  if (mem_layout.initialized) {
    clean_memory_segment(&mem_layout.heap, 0);
    clean_memory_segment(&mem_layout.stack, 1);
    clean_memory_segment(&mem_layout.global, 1);
    clean_memory_segment(&mem_layout.tls, 1);
  }
}
/* }}} */

/** Shadow access {{{
 *
 * In a typical case shadow regions reside in the high memory but below
 * stack. Provided that shadow displacement offsets are stored using
 * unsigned, integers computing some shadow address `S` of an application-space
 * address `A` using a shadow displacement offset `OFF` is as follows:
 *
 *  Stack address:
 *    S = A - OFF
 *  Global, heap of RTL address:
 *    S = A + OFF
 *
 * Conversions between application-space and shadow memory addresses
 * are given using the following macros.
*/

/*! \brief General macro for computing shadow address
 * @param _addr - an address in application space
 * @param _offset - a shadow displacement offset
 * @param _direction - plus or minus sign */
#define SHADOW_ACCESS(_addr,_offset,_direction)  \
  ((uintptr_t)((uintptr_t)_addr _direction _offset))

/*! \brief Access to shadow area situated lower than an application segment */
#define LOWER_SHADOW_ACCESS(_addr,_offset) \
  SHADOW_ACCESS(_addr,_offset,-)

/*! \brief Access to shadow area situated higher than an application segment */
#define HIGHER_SHADOW_ACCESS(_addr,_offset) \
  SHADOW_ACCESS(_addr,_offset,+)

/*! \brief Convert a stack address into its primary shadow counterpart */
#define PRIMARY_STACK_SHADOW(_addr) \
  LOWER_SHADOW_ACCESS(_addr, mem_layout.stack.prim_offset)

/*! \brief Convert a stack address into its secondary shadow counterpart */
#define SECONDARY_STACK_SHADOW(_addr) \
  LOWER_SHADOW_ACCESS(_addr, mem_layout.stack.sec_offset)

/*! \brief Convert a global address into its primary shadow counterpart */
#define PRIMARY_GLOBAL_SHADOW(_addr)  \
  HIGHER_SHADOW_ACCESS(_addr, mem_layout.global.prim_offset)

/*! \brief Convert a global address into its secondary shadow counterpart */
#define SECONDARY_GLOBAL_SHADOW(_addr) \
  HIGHER_SHADOW_ACCESS(_addr, mem_layout.global.sec_offset)

/*! \brief Convert a TLS address into its primary shadow counterpart */
#define PRIMARY_TLS_SHADOW(_addr)  \
  HIGHER_SHADOW_ACCESS(_addr, mem_layout.tls.prim_offset)

/*! \brief Convert a TLS address into its secondary shadow counterpart */
#define SECONDARY_TLS_SHADOW(_addr) \
  HIGHER_SHADOW_ACCESS(_addr, mem_layout.tls.sec_offset)

/*! \brief Select stack or global shadow based on the value of `_global`
 *
 * - PRIMARY_SHADOW(_addr, 0) is equivalent to PRIMARY_STACK_SHADOW(_addr)
 * - PRIMARY_SHADOW(_addr, 1) is equivalent to PRIMARY_GLOBAL_SHADOW(_addr) */
#define PRIMARY_SHADOW(_addr, _global) \
  (_global ? PRIMARY_GLOBAL_SHADOW(_addr) : PRIMARY_STACK_SHADOW(_addr))

/*! \brief Same as above but for secondary stack/global shadows */
#define SECONDARY_SHADOW(_addr, _global) \
  (_global ? SECONDARY_GLOBAL_SHADOW(_addr) : SECONDARY_STACK_SHADOW(_addr))

/*! \brief Convert a heap address into its shadow counterpart */
#define HEAP_SHADOW(_addr) \
  HIGHER_SHADOW_ACCESS(_addr, mem_layout.heap.prim_offset)
/* }}} */

/** Memory segment ranges {{{ */
/*! \brief Evaluate to a true value if a given address resides within a given
 * memory segment. */
#define IS_ON(_addr,_seg) ( \
  ((uintptr_t)_addr) >= _seg.start && \
  ((uintptr_t)_addr) <= _seg.end \
)

/*! \brief Evaluate to true if _addr is a heap address */
#define IS_ON_HEAP(_addr) IS_ON(_addr, mem_layout.heap)

/*! \brief Evaluate to true if _addr is a stack address */
#define IS_ON_STACK(_addr) IS_ON(_addr, mem_layout.stack)

/*! \brief Evaluate to true if _addr is a global address */
#define IS_ON_GLOBAL(_addr) IS_ON(_addr, mem_layout.global)

/*! \brief Evaluate to true if _addr is a TLS address */
#define IS_ON_TLS(_addr) IS_ON(_addr, mem_layout.tls)

/*! \brief Shortcut for evaluating an address via ::IS_ON_STACK or
 * ::IS_ON_GLOBAL based on the value of the second parameter */
#define IS_ON_STATIC(_addr, _global) \
  (_global ? IS_ON_GLOBAL(_addr) : IS_ON_STACK(_addr))

/*! \brief Evaluate to a true value if a given address belongs to tracked
 * allocation (i.e., found within stack, heap or globally) */
#define IS_ON_VALID(_addr) \
  (IS_ON_STACK(_addr) || IS_ON_HEAP(_addr) || IS_ON_GLOBAL(_addr))
/* }}} */
