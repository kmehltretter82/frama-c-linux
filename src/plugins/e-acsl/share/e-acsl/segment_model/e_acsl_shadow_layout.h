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

/*! \brief The first address past the end of the uninitialized data (BSS)
 * segment . */
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
#define KB_SZ(_s) (_s/MB) //!< Convert bytes to kilobytes
#define MB_SZ(_s) (_s/MB) //!< Convert bytes to megabytes
#define GB_SZ(_s) (_s/GB) //!< Convert bytes to gigabytes

/*! \brief Size of the heap shadow */
#define HEAP_SHADOW_SIZE (1024 * MB)

/*! \brief Size of a stack shadow */
#define STACK_SHADOW_SIZE (72 * MB)

/*! \brief Pointer size (in bytes) for a given system */
#define PTR_SZ sizeof(uintptr_t)

/*! \brief Bit and byte sizes of a unsigned long type, i.e., the largest
 * integer type that can be used with bit-level operators.
 * NB: Some architectures allow 128-bit (i.e., 16 byte integers),
 * but the availability of such integer types is implementation specific. */
#define ULONG_BYTES 8
#define ULONG_BITS 64

/* Program stack information {{{ */
extern char ** environ;

/*! \brief Return greatest (known) address on a program's stack.
 * This function presently determines the address using the address of the
 * last string in `environ`. That is, it assumes that argc and argv are
 * stored below environ, which holds for GCC/GLIBC but is not necessarily
 * true. In general, a reliable way of detecting the upper bound of a stack
 * segment is needed. */
static uintptr_t get_stack_end(int *argc_ref,  char *** argv_ref) {
  char **env = environ;
  while (env[1])
    env++;
  uintptr_t addr = (uintptr_t)*env + strlen(*env);

  /* When returning the end stack addess we need to make sure that
   * ::ULONG_BITS past that address are actually writable. This is
   * to be able to set initialization and read-only bits ::ULONG_BITS
   * at a time. If not respected, this may cause a segfault in
   * ::argv_alloca. */
  return addr + ULONG_BITS;
}

/*! \brief Get the stack size (in bytes) as used by the program. The return
 * value is the soft stack limit, i.e., it can be programmatically increased
 * at runtime */
static size_t get_stack_size() {
  struct rlimit rlim;
  assert(!getrlimit(RLIMIT_STACK, &rlim));
  return rlim.rlim_cur;
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

/* Program Layout {{{ */

/* Memory segments ************************************************************
 *  ----------------------------------------> Maximal address
 *  Kernel Segment
 *  ---------------------------------------->
 *  Environment Segment [ argc, argv, env ]
 * -----------------------------------------> Stack End Address
 *  Program Stack Segment [ Used stack ]
 * -----------------------------------------> Stack Start Address
 *  Unused Stack Segment
 * -----------------------------------------> Stack Soft Bound Address
 *  Stack Grow Segment
 * ----------------------------------------->
 *  Lib Segment
 * -----------------------------------------> Stack Shadow Start Address
 *  Stack Shadow Region
 * -----------------------------------------> Stack Shadow End Address
 *  Unused Space Segment
 * ----------------------------------------->
 *  Heap Shadow Region
 * -----------------------------------------> Heap Shadow Start Address
 * -----------------------------------------> Heap End Address
 *  Heap
 * -----------------------------------------> Heap Start Address [Initial Brk]
 *  BSS Segment  [ Uninitialised Globals ]
 * ----------------------------------------->
 *  Data Segment [ Initialised Globals   ]
 * ----------------------------------------->
 *  Text Segment [ Constants ]
 * -----------------------------------------> NULL (minimal address)
******************************************************************************/

static struct program_layout pgm_layout;

/*! \brief Structure for tracking shadow regions and boundaries of memory
 * segments. */
struct program_layout {
  uintptr_t stack_start; //!< Least address in program stack
  uintptr_t stack_end; //!< Greatest address in program stack.
  uintptr_t stack_soft_bound; /*!< \brief Address of the soft stack bound.
   A program using stack addresses beyond (i.e., less than) the soft bound
   runs into a stack overflow. */
  size_t stack_shadow_size; /*!< \brief Size (in bytes) of a stack shadow.
    Same size if used for short and long shadow regions. */

  uintptr_t short_stack_shadow_start; //!< Least address in short shadow region
  uintptr_t short_stack_shadow_end; //!< Greatest address in short shadow region
  uintptr_t short_stack_shadow_offset; /*!< \brief Short shadow offset.
    The offset is kept as a positive (unsigned) integer
    relative to the stack shadow region situated below the stack. That is,
    to get a shadow address from an actual one the offset needs to be
    subtracted. */

  uintptr_t long_stack_shadow_start; //!< Least address in long shadow region
  uintptr_t long_stack_shadow_end; //!< Greatest address in long shadow region
  uintptr_t long_stack_shadow_offset; /*!< \brief Long shadow offset. Similar
    to #short_stack_shadow_offset */

  uintptr_t heap_start; //!<  Least address in a program's heap.
  uintptr_t heap_end; //!<  Greatest address in a program's heap.

  uintptr_t heap_shadow_start; /*!< \brief Least address in a program's shadow
                                 heap region. */
  uintptr_t heap_shadow_end; /*!< \brief Greatest address in a program's
                               shadow heap region. */
  size_t heap_shadow_size; //!< Size (in bytes) of the heap shadow region. */
  uintptr_t heap_shadow_offset;  /*!< \brief Short shadow offset.
   * The offset is kept as a positive (unsigned) integer
   * relative to the heap shadow region situated above the heap. That is,
   * unlike stack shadow, to get a shadow address from an actual one the
   * offset needs to be added. */

  /* Same as `stack_...` but for shadowing globals */
  uintptr_t global_end;
  uintptr_t global_start;
  size_t global_shadow_size;

  uintptr_t short_global_shadow_end;
  uintptr_t short_global_shadow_start;
  uintptr_t short_global_shadow_offset;

  uintptr_t long_global_shadow_end;
  uintptr_t long_global_shadow_start;
  uintptr_t long_global_shadow_offset;

  /*! Carries a non-zero value if shadow layout has been initialized and
   * evaluates to zero otehrwise. */
  int initialized;
};

/*! \brief Setting program layout for analysys, namely:
 *  - Detect boundaries of different program segments
 *  - Allocate shadow regions (1 heap region + 2 stack regions)
 *  - Compute shadow offsets
 *
 *  *TODO*: This function should be a part of ::__e_acsl_memory_init visible
 *  externally */
static void init_pgm_layout(int *argc_ref, char ***argv_ref) {
  DLOG("<<< Initialize shadow layout >>>\n");
  /* Setting up stack. Stack grows downwards starting from the stack end
   * address (i.e., the address of the stack pointer) at the time of
   * initialization. */
  pgm_layout.stack_shadow_size = STACK_SHADOW_SIZE;
  pgm_layout.stack_end = get_stack_end(argc_ref, argv_ref);
  pgm_layout.stack_start =
    pgm_layout.stack_end - pgm_layout.stack_shadow_size;
  /* Soft bound can be increased programmatically, thus detecting
   * stack overflows using this stack bound needs to take into account such
   * changes. Very approximate for the moment,  */
  pgm_layout.stack_soft_bound = pgm_layout.stack_end - get_stack_size();

  /* Short (byte) stack shadow region */
  void * short_stack_shadow = do_mmap(pgm_layout.stack_shadow_size);
  pgm_layout.short_stack_shadow_start = (uintptr_t)short_stack_shadow;
  pgm_layout.short_stack_shadow_end =
    (uintptr_t)short_stack_shadow + pgm_layout.stack_shadow_size;
  pgm_layout.short_stack_shadow_offset =
    pgm_layout.stack_end - pgm_layout.short_stack_shadow_end;

  /* Long (block) stack shadow region */
  void *long_stack_shadow  = do_mmap(pgm_layout.stack_shadow_size);
  pgm_layout.long_stack_shadow_start = (uintptr_t)long_stack_shadow;
  pgm_layout.long_stack_shadow_end =
    (uintptr_t)long_stack_shadow + pgm_layout.stack_shadow_size;
  pgm_layout.long_stack_shadow_offset =
    pgm_layout.stack_end - pgm_layout.long_stack_shadow_end;

  /* Setting heap. Heap grows upwards starting from the current program break.
   Alternative approach would be to use the end of BSS but in fact the end of
   BSS and the current program break are not really close to each other, so
   some space will be wasted.  Another reason is that sbrk is likely to return
   an aligned address which makes the access faster. */
  pgm_layout.heap_start = (uintptr_t)sbrk(0);
  pgm_layout.heap_shadow_size = HEAP_SHADOW_SIZE;
  pgm_layout.heap_end = pgm_layout.heap_start + pgm_layout.heap_shadow_size;

  void* heap_shadow = do_mmap(pgm_layout.heap_shadow_size);
  pgm_layout.heap_shadow_start = (uintptr_t)heap_shadow;
  pgm_layout.heap_shadow_end =
    (uintptr_t)heap_shadow + pgm_layout.heap_shadow_size;
  pgm_layout.heap_shadow_offset =
    pgm_layout.heap_shadow_start - pgm_layout.heap_start;

  /* Setting shadow for globals */
  /* In all likelihood it is reasonably safe to assume that first
   * 2x*pointer-size bytes of the memory space will not be used. */
  pgm_layout.global_start = PTR_SZ*2;
  pgm_layout.global_end = (uintptr_t)&end;
  pgm_layout.global_shadow_size
    = pgm_layout.global_end - pgm_layout.global_start;

  /* Short (byte) global shadow region */
  void * short_global_shadow = do_mmap(pgm_layout.global_shadow_size);
  pgm_layout.short_global_shadow_start = (uintptr_t)short_global_shadow;
  pgm_layout.short_global_shadow_end =
    (uintptr_t)short_global_shadow + pgm_layout.global_shadow_size;
  pgm_layout.short_global_shadow_offset =
    pgm_layout.short_global_shadow_start - pgm_layout.global_start;

  /* Long (block) global shadow region */
  void *long_global_shadow  = do_mmap(pgm_layout.global_shadow_size);
  pgm_layout.long_global_shadow_start = (uintptr_t)long_global_shadow;
  pgm_layout.long_global_shadow_end =
    (uintptr_t)long_global_shadow + pgm_layout.global_shadow_size;
  pgm_layout.long_global_shadow_offset =
    pgm_layout.long_global_shadow_end - pgm_layout.global_end;

  /* The shadow layout has been initialized */
  pgm_layout.initialized = 1;
}

/*! \brief Unmap (de-allocate) shadow regions used by runtime analysis */
static void clean_pgm_layout() {
  DLOG("<<< Clean shadow layout >>>\n");
  /* Unmap global shadows */
  if (pgm_layout.long_global_shadow_start)
    munmap((void*)pgm_layout.long_global_shadow_start,
      pgm_layout.global_shadow_size);
  if (pgm_layout.short_global_shadow_start)
    munmap((void*)pgm_layout.short_global_shadow_start,
      pgm_layout.global_shadow_size);
  /* Unmap stack shadows */
  if (pgm_layout.long_stack_shadow_start)
    munmap((void*)pgm_layout.long_stack_shadow_start,
      pgm_layout.stack_shadow_size);
  if (pgm_layout.short_stack_shadow_start)
    munmap((void*)pgm_layout.short_stack_shadow_start,
      pgm_layout.stack_shadow_size);
  /* Unmap heap shadow */
  if (pgm_layout.heap_shadow_start)
    munmap((void*)pgm_layout.heap_shadow_start, pgm_layout.heap_shadow_size);
}
/* }}} */

/* Shadow access {{{
 *
 * In a typical case shadow regions reside in the high memory but below the
 * stack segment. Provided that shadow displacement offsets are stored using
 * unsigned, integers computing some shadow address `S` of an application-space
 * address `A` using a shadow displacement offset `OFF` is as follows:
 *
 *  Stack address:
 *    S = A - OFF
 *  Global or heap address:
 *    S = A + OFF
 *
 * Conversions between application-space and shadow memory addresses
 * are given using the following macros.
*/

/*! \brief Convert a stack address into its short (byte) shadow counterpart */
#define SHORT_STACK_SHADOW(_addr)  \
  ((uintptr_t)((uintptr_t)_addr - pgm_layout.short_stack_shadow_offset))
/*! \brief Convert a stack address into its long (block) shadow counterpart */
#define LONG_STACK_SHADOW(_addr) \
  ((uintptr_t)((uintptr_t)_addr - pgm_layout.long_stack_shadow_offset))

/*! \brief Convert a global address into its short (byte) shadow counterpart */
#define SHORT_GLOBAL_SHADOW(_addr)  \
  ((uintptr_t)((uintptr_t)_addr + pgm_layout.short_global_shadow_offset))
/*! \brief Convert a global address into its long (block) shadow counterpart */
#define LONG_GLOBAL_SHADOW(_addr) \
  ((uintptr_t)((uintptr_t)_addr + pgm_layout.long_global_shadow_offset))

/*! \brief Select stack or global shadow based on the value of `_global`
 *
 * - SHORT_SHADOW(_addr, 0) is equivalent to STACK_SHORT_SHADOW(_addr)
 * - SHORT_SHADOW(_addr, 1) is equivalent to GLOBAL_SHORT_SHADOW(_addr) */
#define SHORT_SHADOW(_addr, _global) \
  (_global ? SHORT_GLOBAL_SHADOW(_addr) : SHORT_STACK_SHADOW(_addr))

/*! \brief Same as above but for long stack/global shadows */
#define LONG_SHADOW(_addr, _global) \
  (_global ? LONG_GLOBAL_SHADOW(_addr) : LONG_STACK_SHADOW(_addr))

/*! \brief Convert a heap address into its shadow counterpart */
#define HEAP_SHADOW(_addr)  \
  ((uintptr_t)((uintptr_t)_addr + pgm_layout.heap_shadow_offset))

/*! \brief Evaluate to a true value if a given address is a heap address */
#define IS_ON_HEAP(_addr) ( \
  ((uintptr_t)_addr) >= pgm_layout.heap_start && \
  ((uintptr_t)_addr) <= pgm_layout.heap_end \
)

/*! \brief Evaluate to a true value if a given address is a stack address */
#define IS_ON_STACK(_addr) ( \
  ((uintptr_t)_addr) >= pgm_layout.stack_start && \
  ((uintptr_t)_addr) <= pgm_layout.stack_end \
)

/*! \brief Evaluate to a true value if a given address is a global address */
#define IS_ON_GLOBAL(_addr) ( \
  ((uintptr_t)_addr) >= pgm_layout.global_start && \
  ((uintptr_t)_addr) <= pgm_layout.global_end \
)

/*! \brief Shortcut for evaluating an address via ::IS_ON_STACK or
 * ::IS_ON_GLOBAL based on the valua of the second parameter */
#define IS_ON_STATIC(_addr, _global) \
  (_global ? IS_ON_GLOBAL(_addr) : IS_ON_STACK(_addr))

/*! \brief Evaluate to a true value if a given address belongs to tracked
 * allocation (i.e., found within stack, heap oor globally) */
#define IS_ON_VALID(_addr) \
  (IS_ON_STACK(_addr) || IS_ON_HEAP(_addr) || IS_ON_GLOBAL(_addr))
/* }}} */
