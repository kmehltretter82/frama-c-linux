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
 * \file  e_acsl_shadow_layout.h
 * \brief Setup for memory tracking using shadowing
***************************************************************************/

#ifndef E_ACSL_SHADOW_LAYOUT
#define E_ACSL_SHADOW_LAYOUT

#include <stddef.h>
#include <stdint.h>
#include "../../internals/e_acsl_malloc.h"

/* Default size of a program's heap tracked via shadow memory */
#ifndef E_ACSL_HEAP_SIZE
#define E_ACSL_HEAP_SIZE 512
#endif

/* Default size of a program's stack tracked via shadow memory */
#ifndef E_ACSL_STACK_SIZE
#define E_ACSL_STACK_SIZE 64
#endif

/* Symbols exported by the linker script */

/*!\brief The first address past the end of the text segment. */
extern char etext;
/*!\brief The first address past the end of the initialized data segment. */
extern char edata;
/*!\brief The first address past the end of the uninitialized data segment. */
extern char end;
/*!\brief The first address of a program. */
extern char __executable_start;

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

/*! \brief Byte-width of a pointer */
#define PTR_SZ sizeof(uintptr_t)

/*! \brief Byte-width of the largest integer type usable with bitwise
 * operators */
#define ULONG_BYTES 8
/*! \brief Bit-width of the largest integer type usable with bitwise
 * operators */
#define ULONG_BITS 64

/** Hardcoded sizes of tracked program segments {{{ */
/*! \brief Size of a program's heap */
#define PGM_HEAP_SIZE (E_ACSL_HEAP_SIZE * MB)

/*! \brief Size of a program's Thread-local storage (TLS).
  Standard streams stdin, stdout and stderr are put here.
  Some libraries such as libxml use it quite a lot:
  it may occur that the given size is not enough,
  in which case it MUST be increased. */
#ifndef PGM_TLS_SIZE
#define PGM_TLS_SIZE (64 * MB)
#endif

/*! \brief Mspace padding used by shadow segments. This is to make sure that
 * some allocation which exceeds the size of an initial memspace does not
 * move the mspace somewhere else. 512KB is a bit of an overkill, but should
 * not hurt too much in general unless memory space is really a constraint */
#define SHADOW_SEGMENT_PADDING (512*KB)
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

/* }}} */

/** Program stack information {{{ */
extern char ** environ;

/*! \brief Set a new soft stack limit
 *
 * If the new stack size is greater than the max stack size, then set to the max
 * stack size. If the new stack size is less than the current stack size, don't
 * do anything.
 *
 * Abort if an error occur when retrieving or setting the stack size.
 *
 * \param size - new stack size in bytes
 * \return the new stack size in bytes.
 */
size_t increase_stack_limit(const size_t size);

/*! \brief Return byte-size of a program's stack. The return value is the soft
 * stack limit, i.e., it can be programmatically increased at runtime. */
size_t get_stack_size();

/*! \brief Return greatest (known) address on a program's stack.
 * This function presently determines the address using the address of the
 * last string in `environ`. That is, it assumes that argc and argv are
 * stored below environ, which holds for GCC/Glibc but is not necessarily
 * true for some other compilers/libraries. */
uintptr_t get_stack_start(int *argc_ref,  char *** argv_ref);
/* }}} */

/** Program heap information {{{ */
/*! \brief Return the start address of a program's heap. */
uintptr_t get_heap_start();

/*! \brief Return the tracked size of a program's heap. */
size_t get_heap_size();

/*! \brief Return the size of a secondary shadow region tracking
 * initialization (i.e., init shadow). */
size_t get_heap_init_size();

/** }}} */

/** Program global information {{{ */
/*! \brief Return the start address of a segment holding globals (generally
 * BSS and Data segments). */
uintptr_t get_global_start();

/*! \brief Return byte-size of global segment */
size_t get_global_size();
/** }}} */

/** Shadow Layout {{{ */
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
  In reality layouts may vary. Also, with mmap allocations heap does not
  necessarily grows from program break upwards. Typically mmap will allocate
  memory somewhere closer to stack. */

/* Struct representing a contigous memory region. Effectively this describes
 * a memory segment, such as heap, stack or segments in the shadow memory
 * used to track them. */
struct memory_segment {
  const char *name; //!< Symbolic name
  size_t    size; //!< Byte-size
  uintptr_t start; //!< Least address
  uintptr_t end; //!< Greatest address
  mspace    mspace; // !< Mspace used for the partition
  /* The following are only set if the segment is a shadow segment */
  struct memory_segment *parent; //!< Pointer to the tracked segment
  size_t shadow_ratio; //!< Ratio of shadow to application memory
  /*!< Offset between the start of the tracked segment and the start of this
     segment */
  intptr_t shadow_offset;
};

typedef struct memory_segment memory_segment;

/* Struct representing a memory segment along with information about its
 * shadow spaces. */
struct memory_partition {
  memory_segment application; /* Application memory segment */
  memory_segment primary; /* Primary shadow segment */
  memory_segment secondary; /* Secondary shadow segment */
#ifdef E_ACSL_TEMPORAL
  memory_segment temporal_primary; /* Primary temporal shadow segment */
  memory_segment temporal_secondary; /* Secondary temporal shadow segment */
#endif
};

typedef struct memory_partition memory_partition;

/* Struct representing memory layout of a program consisting of heap, stack,
   global and tls segments */
struct memory_layout {
  memory_partition heap;
  memory_partition stack;
  memory_partition global;
  memory_partition tls;
  int is_initialized;
};

/*! \brief Full program memory layout. */
struct memory_layout mem_layout;

/*! \brief Array of used partitions */
memory_partition *mem_partitions [] = {
  &mem_layout.heap,
  &mem_layout.stack,
  &mem_layout.global,
  &mem_layout.tls
};

/*! \brief Initialize an application memory segment.
 *
 * \param seg - pointer to a segment to initialize
 * \param start - least address in an application's segment
 * \param size - size in bytes
 * \param name - segment name
 * \param msp - mspace used for this segment (defined only for heap) */
void set_application_segment(memory_segment *seg, uintptr_t start,
    size_t size, const char *name, mspace msp);

/*! \brief Set a shadow memory segment
 *
 * \param seg - pointer to a segment to initialize
 * \param parent - pointer to the segment ::seg tracks. Should be initialized
 * \param ratio - ratio of shadow to application memory
 * \param name - symbolic name of the segment
 */
void set_shadow_segment(memory_segment *seg, memory_segment *parent,
    size_t ratio, const char *name);

/*! \brief Initialize memory layout, i.e., determine bounds of program segments,
 * allocate shadow memory spaces and compute offsets. This function populates
 * global struct ::memory_layout holding that information with data.
   Case of the stack. */
void init_shadow_layout_stack(int *argc_ref, char ***argv_ref);

/*! \brief Return start address of a program's TLS */
uintptr_t get_tls_start();

/*! \brief Initialize memory layout, i.e., determine bounds of program segments,
 * allocate shadow memory spaces and compute offsets. This function populates
 * global struct ::memory_layout holding that information with data.
   Case of the heap, globals and tls. */
void init_shadow_layout_heap_global_tls();

/*! \brief Deallocate shadow regions used by runtime analysis */
void clean_shadow_layout();
/* }}} */

/** Shadow access {{{
 *
 * Shadow displacement offsets are stored using signed integers.
 * Displacement offset between an application memory space Ma and a shadow
 * memory space Ms is computed by [min(Ma) - min(Ms)], where min(Ma) and min(Ms)
 * denote least addresses in application and shadow spaces Ma and Ms respectively.
 *
 * Correspondense between a shadow address S and an application address A
 * using a displacement offset OFF is therefore as follows:
 *    OFF = A - S
 *    S = A - OFF
 *    A = S + OFF
 *
 * Conversions between application-space and shadow memory addresses
 * are given by following macros.
*/

#define heap_primary_offset     mem_layout.heap.primary.shadow_offset
#define heap_secondary_offset   mem_layout.heap.secondary.shadow_offset
#define stack_primary_offset    mem_layout.stack.primary.shadow_offset
#define stack_secondary_offset  mem_layout.stack.secondary.shadow_offset
#define global_primary_offset   mem_layout.global.primary.shadow_offset
#define global_secondary_offset mem_layout.global.secondary.shadow_offset
#define tls_primary_offset      mem_layout.tls.primary.shadow_offset
#define tls_secondary_offset    mem_layout.tls.secondary.shadow_offset

/*! \brief Compute a shadow address using displacement offset
 * @param _addr - an application space address
 * @param _offset - a shadow displacement offset */
#define SHADOW_ACCESS(_addr,_offset)  \
  ((intptr_t)((intptr_t)_addr - (intptr_t)_offset))

/*! \brief Same as SHADOW_ACCESS but with an additional scale factor given via
 * _scale argument. Scale factor describes ratio of application to shadow bytes,
 * for instance if one bit shadow memory is used to track one byte of
 * application memory then the scale factor is 8.
 * Here, scale factor is the ration of application to shadow memory. */
#define SCALED_SHADOW_ACCESS(_addr, _start, _offset, _scale)  \
  (((uintptr_t)_start - _offset) + \
   ((uintptr_t)_addr - (uintptr_t)_start)/_scale)

/*! \brief Convert a heap address into its shadow counterpart */
#define HEAP_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, heap_primary_offset)

/*! \brief Convert a heap address into its init shadow counterpart */
#define HEAP_INIT_SHADOW(_addr) \
  SCALED_SHADOW_ACCESS(_addr, \
      mem_layout.heap.application.start, \
      mem_layout.heap.secondary.shadow_offset, \
      mem_layout.heap.secondary.shadow_ratio)

#define HEAP_START mem_layout.heap.application.start

/*! \brief Convert a stack address into its primary shadow counterpart */
#define PRIMARY_STACK_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, stack_primary_offset)

/*! \brief Convert a stack address into its secondary shadow counterpart */
#define SECONDARY_STACK_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, stack_secondary_offset)

/*! \brief Convert a global address into its primary shadow counterpart */
#define PRIMARY_GLOBAL_SHADOW(_addr)  \
  SHADOW_ACCESS(_addr, global_primary_offset)

/*! \brief Convert a global address into its secondary shadow counterpart */
#define SECONDARY_GLOBAL_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, global_secondary_offset)

/*! \brief Convert a TLS address into its primary shadow counterpart */
#define PRIMARY_TLS_SHADOW(_addr)  \
  SHADOW_ACCESS(_addr, tls_primary_offset)

/*! \brief Convert a TLS address into its secondary shadow counterpart */
#define SECONDARY_TLS_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, tls_secondary_offset)

/* \brief Compute a primary or a secondary shadow address (based on the value of
 * parameter `_region`) of an address tracked via an offset-based encoding.
 * For an untracked address `0` is returned. */
#define SHADOW_REGION_ADDRESS(_addr, _region) \
  (IS_ON_STACK(_addr) ? _region##_STACK_SHADOW(_addr) : \
    IS_ON_GLOBAL(_addr) ? _region##_GLOBAL_SHADOW(_addr) : \
      IS_ON_TLS(_addr) ? _region##_TLS_SHADOW(_addr) : 0)

/*! \brief Primary shadow address of a non-dynamic region */
#define PRIMARY_SHADOW(_addr) SHADOW_REGION_ADDRESS(_addr, PRIMARY)
/*! \brief Secondary shadow address of a non-dynamic region */
#define SECONDARY_SHADOW(_addr) SHADOW_REGION_ADDRESS(_addr, SECONDARY)

/* }}} */

/** Memory segment ranges {{{ */
/*! \brief Evaluate to a true value if address _addr resides within a given
 * memory segment.
 * \param _addr - a memory address
 * \param _seg - a memory segment (one of the structs within ::mem_layout)
*/
#define IS_ON(_addr,_seg) ( \
  ((uintptr_t)_addr) >= _seg.start && \
  ((uintptr_t)_addr) <= _seg.end \
)

/*! \brief Evaluate to true if `_addr` is a heap address */
#define IS_ON_HEAP(_addr) IS_ON(_addr, mem_layout.heap.application)

/*! \brief Evaluate to true if `_addr` is a stack address */
#define IS_ON_STACK(_addr) IS_ON(_addr, mem_layout.stack.application)

/*! \brief Evaluate to true if `_addr` is a global address */
#define IS_ON_GLOBAL(_addr) IS_ON(_addr, mem_layout.global.application)

/*! \brief Evaluate to true if _addr is a TLS address */
#define IS_ON_TLS(_addr) IS_ON(_addr, mem_layout.tls.application)

/*! \brief Shortcut for evaluating an address via ::IS_ON_STACK,
 * ::IS_ON_GLOBAL or ::IS_ON_TLS  */
#define IS_ON_STATIC(_addr) \
  (IS_ON_STACK(_addr) || IS_ON_GLOBAL(_addr) || IS_ON_TLS(_addr))

/*! \brief Evaluate to a true value if a given address belongs to tracked
 * allocation (i.e., found within tls, stack, heap or globally) */
#define IS_ON_VALID(_addr) \
  (IS_ON_STACK(_addr) || IS_ON_HEAP(_addr) || \
   IS_ON_GLOBAL(_addr) || IS_ON_TLS(_addr))
/* }}} */

#ifdef E_ACSL_TEMPORAL /* {{{ */
/*! \brief Convert a heap address into its shadow counterpart */
#define TEMPORAL_HEAP_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, mem_layout.heap.temporal_primary.shadow_offset)

/*! \brief Convert a stack address into its primary temporal shadow counterpart */
#define TEMPORAL_PRIMARY_STACK_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, mem_layout.stack.temporal_primary.shadow_offset)

/*! \brief Convert a stack address into its secondary temporal shadow counterpart */
#define TEMPORAL_SECONDARY_STACK_SHADOW(_addr) \
  SHADOW_ACCESS(_addr, mem_layout.stack.temporal_secondary.shadow_offset)

/*! \brief Convert a global address into its primary temporal shadow counterpart */
#define TEMPORAL_PRIMARY_GLOBAL_SHADOW(_addr)  \
  SHADOW_ACCESS(_addr, mem_layout.global.temporal_primary.shadow_offset)

/*! \brief Convert a global address into its primary temporal shadow counterpart */
#define TEMPORAL_SECONDARY_GLOBAL_SHADOW(_addr)  \
  SHADOW_ACCESS(_addr, mem_layout.global.temporal_secondary.shadow_offset)

/*! \brief Convert a TLS address into its primary temporal shadow counterpart */
#define TEMPORAL_PRIMARY_TLS_SHADOW(_addr)  \
  SHADOW_ACCESS(_addr, mem_layout.tls.temporal_primary.shadow_offset)

/*! \brief Convert a TLS address into its secondary temporal shadow counterpart */
#define TEMPORAL_SECONDARY_TLS_SHADOW(_addr)  \
  SHADOW_ACCESS(_addr, mem_layout.tls.temporal_secondary.shadow_offset)

/*! \brief Temporal primary shadow address of a non-dynamic region */
#define TEMPORAL_PRIMARY_STATIC_SHADOW(_addr) \
  SHADOW_REGION_ADDRESS(_addr, TEMPORAL_PRIMARY)

/*! \brief Temporal secondary shadow address of a non-dynamic region */
#define TEMPORAL_SECONDARY_STATIC_SHADOW(_addr) \
  SHADOW_REGION_ADDRESS(_addr, TEMPORAL_SECONDARY)
#endif /* }}} */

#endif // E_ACSL_SHADOW_LAYOUT
