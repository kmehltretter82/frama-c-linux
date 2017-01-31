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
 * \file  e_acsl_segment_tracking.h
 * \brief Core functionality of the segment-based memory model
***************************************************************************/

/* Segment settings and shadow values interpretation {{{ */

/* This file implements segment-based and offset-based shadow memory models
 * (shadow encodings) (see draft of the PLDI'17 paper).
 *
 * IMPORTANT: While the implementation of the offset-based encoding mostly
 * follows the description given by the paper, there are differences in the
 * segment-based encoding for tracking heap memory. Some of these differences
 * are as follows:
 *  1) Size of a heap segment is increased to 32 bytes
 *  2) Heap meta-segments are no longer used, segment-based representation of
 *    a heap block considers only block segments, such that:
 *    - Lowest `intptr_t` bytes of each shadow segment tracking an application
 *      block store the base address of that block;
 *    - `intptr_t` bytes of the first segment following the initial `intptr_t`
 *      bytes store the length of the block. Note, the length is only stored
 *      by the first segment.
 *  3) Per-byte initialization of application bytes is tracked via a disjoint
 *    shadow region, which maps one bit of shadow memory to a byte of
 *    application memory. Comments within this file often refer to a shadow
 *    region tracking application blocks by segments as to `block shadow`,
 *    and to the region tracking initialization as to `init shadow`.
*/

/*! @brief Byte size of a heap segment.
 * This size is potentially used as an argument to `memalign`.
 * It SHOULD be a multiple of 2 and a multiple of a pointer size.
 *
 * \b FIXME: in the current implementation there might be issues with segment
 * size greater than 64 bytes. This is because presently some initialization
 * functionality relies on the fact that initialization per segment can be set
 * and/or evaluated using an 8-byte bitmask. */
#define HEAP_SEGMENT 32

/*! \brief Number of bytes required to represent initialization of a segment. */
#define INIT_BYTES (HEAP_SEGMENT/8)

/*! \brief Size (in bytes) of a long block on the stack. */
#define LONG_BLOCK 8

/*! \brief Bit offset in a primary shadow byte that represents initialization. */
#define INIT_BIT 0

/*! \brief Bit offset in a primary shadow byte that represents read-only or
 * read-write access.
 *
 * This is such that the value of 1 is read-only, and 0 is read/write */
#define READONLY_BIT 1

/*! \brief Evaluate to a non-zero value if the size of a memory
 * block indicates that it is a long one */
#define IS_LONG_BLOCK(_size) (_size > LONG_BLOCK)

/*! \brief Offset within a long block that identifies the portion of the block
 * that does not have a corresponding shadow and reuse the shadow of a previous
 * segment.
 * E.g., given a long block of 11 bytes the boundary is 8. Then, bytes [0,7] of
 * the block are shadowed (storing block offset and size) and bytes 8-10 are
 * not. This is because 3 bytes are not sufficient to store size and offset.
 * These remaining bytes reuse the shadow of [0,7]. */
#define LONG_BLOCK_BOUNDARY(_size) (_size - _size%LONG_BLOCK)

/*! \brief Primary shadow of a long block consists of a 8-byte segment + a
 * remainder. For instance, a 18-byte block is represented by two 8-byte
 * segments + 2 bytes.  Each byte of a segment stores an offset in the secondary
 * shadow. The offsets for each such segment can be expressed using the
 * following number obtained by compressing all eight bytes with offsets set
 * into a single block. */
#define LONG_BLOCK_MASK 15913703276567643328UL

/*! \brief 6 higher bytes of a memory cell on stack that belongs to a long
 * memory block store offsets relative to meta-data in the secondary shadow. The
 * offsets start with the below number. E.g., if the bits store 51, then the
 * offset at which to read meta-data is (51 - 48). */
#define LONG_BLOCK_INDEX_START 48

/*! \brief Increase the size to a multiple of a segment size. */
#define ALIGNED_SIZE(_s) \
  (_s + ((_s%HEAP_SEGMENT) ? (HEAP_SEGMENT - _s%HEAP_SEGMENT) : 0))

/*! \brief Given the size of a block return the number of segments
 * that represent that block in the heap shadow */
#define BLOCK_SEGMENTS(_s) (ALIGNED_SIZE(_s)/HEAP_SEGMENT)

/* \brief Maximal size_t value that does not cause overflow via addition
 * when segment size is added. */
const size_t max_allocated = SIZE_MAX - HEAP_SEGMENT;

/* \brief Return actual allocation size which takes into account aligned
 * allocation. In the present implementation it is the requested size of
 * a heap block aligned at a segment boundary */
#define ALLOC_SIZE(_s) \
  (_s > 0 && _s < max_allocated ? ALIGNED_SIZE(_s) : 0)

/*! \brief For short blocks numbers 1 to 36 represent lengths and offsets,
 * such that:
 * - 0 -> length 0, offset 0
 * - 1 -> length 1, offset 0,
 * - 2 -> length 2, offset 0,
 * - 3 -> length 2, offset 1 and so on.
 *
 * The below data is used to identify lengths and offsets:
 * Given x is a number from [1, 36] range:
 *   - short_lengths[x] -> length of a block
 *   - short_offsets[x] -> offset within a block */
static const char short_lengths[] = {
  0,
  1,
  2,2,
  3,3,3,
  4,4,4,4,
  5,5,5,5,5,
  6,6,6,6,6,6,
  7,7,7,7,7,7,7,
  8,8,8,8,8,8,8,8
};

static const char short_offsets[] = {
  0,
  0,
  0,1,
  0,1,2,
  0,1,2,3,
  0,1,2,3,4,
  0,1,2,3,4,5,
  0,1,2,3,4,5,6,
  0,1,2,3,4,5,6,7
};

/*! \brief Mask for marking a heap segment as initialized.
 * For instance, let `uintptr_t *p' point to the start of a heap segment
 * in the heap shadow, then 'p[1] | heap_init_mask` sets initialization bits.
 * NOTE: This approach cannot deal with segments larger than 64 bits. */
static const uint64_t heap_init_mask = ~(ONE << HEAP_SEGMENT);

/*! \brief Masks for checking of initialization of global/stack allocated blocks.
 * A byte allocated globally or on stack is deemed initialized if its
 * least significant bit is set to `1' and uninitialized otherwise.
 * The binary representation is then as follows (assuming the leftmost
 * bit is the least significant one):
 *
 *  00000000 00000000 00000000 00000000 ... (0)
 *  10000000 00000000 00000000 00000000 ... (1)
 *  10000000 10000000 00000000 00000000 ... (257)
 *  10000000 10000000 10000000 00000000 ... (65793)
 *  10000000 10000000 10000000 10000000 ... (16843009)
 *  ...
 *
 * For instance, mark first X bytes of a number N as initialised:
 *    N |= static_init_masks[X] */
static const uint64_t static_init_masks [] = {
  0UL, /* 0 bytes */
  1UL,  /* 1 byte */
  257UL,  /* 2 bytes */
  65793UL,  /* 3 bytes */
  16843009UL,  /* 4 bytes */
  4311810305UL,  /* 5 bytes */
  1103823438081UL,  /* 6 bytes */
  282578800148737UL,	/* 7 bytes */
  72340172838076673UL		/* 8 bytes */
};

/*! \brief Bit masks for setting read-only (second least significant) bits.
 * Binary representation (assuming the least significant bit is the
 * leftmost bit) is follows:
 *
 *  00000000 00000000 00000000 00000000 ... (0)
 *  01000000 00000000 00000000 00000000 ... (2)
 *  01000000 01000000 00000000 00000000 ... (514)
 *  01000000 01000000 01000000 00000000 ... (131586)
 *  01000000 01000000 01000000 01000000 ... (33686018)
 *  ...
 *
 *  For instance, mark first X bytes of a number N as read-only:
 *    N |= static_readonly_masks[X] */
static const uint64_t static_readonly_masks [] = {
  0UL, /* 0 bytes */
  2UL, /* 1 byte */
  514UL, /* 2 bytes */
  131586UL, /* 3 bytes */
  33686018UL, /* 4 bytes */
  8623620610UL, /* 5 bytes */
  2207646876162UL, /* 6 bytes */
  565157600297474UL, /* 7 bytes */
  144680345676153346UL /* 8 bytes */
};
/* }}} */

/* Runtime assertions (debug mode) {{{ */
#ifdef E_ACSL_DEBUG
#define DVALIDATE_ALIGNMENT(_addr) \
  DVASSERT(((uintptr_t)_addr) % HEAP_SEGMENT == 0,  \
      "Heap base address %a is unaligned", _addr)

/* Debug function making sure that the order of program segments is as expected
 * and that the program and the shadow segments used do not overlap. */
static void validate_memory_layout() {
  /* Check that the struct holding memory layout is marked as initialized. */
  DVASSERT(mem_layout.initialized != 0, "Un-initialized shadow layout", NULL);
  /* Make sure the order of program segments is as expected, i.e.,
   * top to bottom: stack -> tls -> heap -> global*/

  #define NO_MEM_SEGMENTS 11
  uintptr_t segments[NO_MEM_SEGMENTS][2] = {
     {mem_layout.stack.start, mem_layout.stack.end},
     {mem_layout.stack.prim_start, mem_layout.stack.prim_end},
     {mem_layout.stack.sec_start, mem_layout.stack.sec_end},
     {mem_layout.tls.start, mem_layout.tls.end},
     {mem_layout.tls.prim_start, mem_layout.tls.prim_end},
     {mem_layout.tls.sec_start, mem_layout.tls.sec_end},
     {mem_layout.global.start, mem_layout.global.end},
     {mem_layout.global.prim_start, mem_layout.global.prim_end},
     {mem_layout.global.sec_start, mem_layout.global.sec_end},
     {mem_layout.heap.start, mem_layout.heap.end},
     {mem_layout.heap.prim_start, mem_layout.heap.prim_end}
  };

  /* Make sure all segments (shadow or otherwise) are disjoint */
  size_t i, j;
  for (int i = 0; i < NO_MEM_SEGMENTS; i++) {
    uintptr_t *src = segments[i];
    DVASSERT(src[0] < src[1],
      "Segment start is greater than segment end %lu < %lu\n", src[0], src[1]);
    for (int j = 0; j < NO_MEM_SEGMENTS; j++) {
      if (i != j) {
        uintptr_t *dest = segments[j];
        DVASSERT(src[1] < dest[0] || src[0] > dest[1],
          "Segment [%lu, %lu] overlaps with segment [%lu, %lu]",
          src[0], src[1], dest[0], dest[1]);
      }
    }
  }

  DVASSERT(mem_layout.stack.end > mem_layout.tls.end,
      "Unexpected location of stack (above tls)", NULL);
  DVASSERT(mem_layout.tls.end > mem_layout.heap.end,
      "Unexpected location of tls (above heap)", NULL);
  DVASSERT(mem_layout.heap.end > mem_layout.global.end,
      "Unexpected location of heap (above global)", NULL);
}

/* Assert that memory layout has been initialized and all segments appear
 * in the expected order */
# define DVALIDATE_SHADOW_LAYOUT validate_memory_layout()

/* Assert that boundaries of a block [_addr, _addr+_size] are within a segment
 * given by `_s`. `_s` is either HEAP, STACK, TLS, GLOBAL or STATIC. */
#define DVALIDATE_IS_ON(_addr, _size, _s) \
  DVASSERT(IS_ON_##_s(_addr), "Address %a not on %s", _addr, #_s); \
  DVASSERT(IS_ON_##_s(_addr+_size), "Address %a not on %s", _addr+_size, #_s)

/* Assert that [_addr, _addr+_size] are within heap segment */
#define DVALIDATE_IS_ON_HEAP(_addr, _size) \
  DVALIDATE_IS_ON(_addr, _size, HEAP)
/* Assert that [_addr, _addr+_size] are within stack segment */
#define DVALIDATE_IS_ON_STACK(_addr, _size) \
  DVALIDATE_IS_ON(_addr, _size, STACK)
/* Assert that [_addr, _addr+_size] are within global segment */
#define DVALIDATE_IS_ON_GLOBAL(_addr, _size) \
  DVALIDATE_IS_ON(_addr, _size, GLOBAL)
/* Assert that [_addr, _addr+_size] are within TLS segment */
#define DVALIDATE_IS_ON_TLS(_addr, _size) \
  DVALIDATE_IS_ON(_addr, _size, TLS)
/* Assert that [_addr, _addr+_size] are within stack, global or TLS segments */
#define DVALIDATE_IS_ON_STATIC(_addr, _size) \
  DVALIDATE_IS_ON(_addr, _size, STATIC)

/* Assert that a memory block [_addr, _addr + _size] is allocated on a
 * program's heap */
# define DVALIDATE_HEAP_ACCESS(_addr, _size) \
    DVASSERT(IS_ON_HEAP(_addr), "Expected heap location: %a\n   ", _addr); \
    DVASSERT(heap_allocated((uintptr_t)_addr, _size), \
       "Operation on unallocated heap block [%a + %lu]\n   ",  _addr, _size)

/* Assert that memory block [_addr, _addr + _size] is allocated on stack, TLS
 * or globally */
# define DVALIDATE_STATIC_ACCESS(_addr, _size) \
    DVASSERT(IS_ON_STATIC(_addr), "Expected location: %a\n   ", _addr); \
    DVASSERT(static_allocated((uintptr_t)_addr, _size), \
       "Operation on unallocated block [%a + %lu]\n   ", _addr, _size)

/* Same as ::DVALIDATE_STATIC_LOCATION but for a single memory location */
# define DVALIDATE_STATIC_LOCATION(_addr) \
    DVASSERT(IS_ON_STATIC(_addr), "Expected location: %a\n   ", _addr); \
    DVASSERT(static_allocated_one((uintptr_t)_addr), \
       "Operation on unallocated block [%a]\n   ", _addr)

/* Assert that a memory block [_addr, _addr + _size] is nullified */
# define DVALIDATE_NULLIFIED(_addr, _size) \
  DVASSERT(zeroed_out((void *)_addr, _size), \
    "Block [%a, %a+%lu] not nullified", _addr, _addr, _size)

#else
/*! \cond exclude from doxygen */
#  define DVALIDATE_SHADOW_LAYOUT
#  define DVALIDATE_HEAP_ACCESS
#  define DVALIDATE_STATIC_ACCESS
#  define DVALIDATE_STATIC_LOCATION
#  define DVALIDATE_ALIGNMENT
#  define DVALIDATE_NULLIFIED
#  define DVALIDATE_IS_ON
#  define DVALIDATE_IS_ON_HEAP
#  define DVALIDATE_IS_ON_STACK
#  define DVALIDATE_IS_ON_GLOBAL
#  define DVALIDATE_IS_ON_TLS
#  define DVALIDATE_IS_ON_STATIC
/*! \endcond */
#endif
/* }}} */

/* E-ACSL predicates {{{ */
/* See definitions for documentation */
static uintptr_t heap_info(uintptr_t addr, char type);
static uintptr_t static_info(uintptr_t addr, char type);
static int heap_allocated(uintptr_t addr, size_t size);
static int static_allocated(uintptr_t addr, long size);
static int freeable(void *ptr);

/*! \brief Quick test to check if a static location belongs to allocation.
 * This macro really belongs where static_allocated is defined, but
 * since it is used across this whole file it needs to be defined here. */
#define static_allocated_one(addr) \
  ((int)PRIMARY_SHADOW(addr))

/*! \brief Shortcut for executing statements based on the segment a given
 * address belongs to.
 * \param intptr_t _addr - a memory address
 * \param code_block _heap_stmt - code executed if `_addr` is a heap address
 * \param code_block _static_stmt - code executed if `_addr` is a static address */
#define TRY_SEGMENT_WEAK(_addr, _heap_stmt, _static_stmt)  \
  if (IS_ON_HEAP(_addr)) { \
    _heap_stmt; \
  } else if (IS_ON_STATIC(_addr)) { \
    _static_stmt; \
  } \

/*! \brief Shortcut for executing statements based on the segment a given
 * address belongs to.
 * \param intptr_t _addr - a memory address
 * \param code_block _heap_stmt - code executed if `_addr` is a heap address
 * \param code_block _static_stmt - code executed if `_addr` is a static address */
#define TRY_SEGMENT_WEAK(_addr, _heap_stmt, _static_stmt)  \
  if (IS_ON_HEAP(_addr)) { \
    _heap_stmt; \
  } else if (IS_ON_STATIC(_addr)) { \
    _static_stmt; \
  } \

/*! \brief Same as TRY_SEGMENT but performs additional checks aborting the
 * execution if the given address is `NULL` or does not belong to known
 * segments. Note that `NULL` also does not belong to any of the tracked
 * segments but it is treated separately for debugging purposes.
 *
 * The \b WEAK notion refers to the behaviour where no action is performed if
 * the given address does not belong to any of the known segments. */
#define TRY_SEGMENT(_addr, _heap_stmt, _static_stmt) { \
  TRY_SEGMENT_WEAK(_addr, _heap_stmt, _static_stmt) \
  else if (_addr == 0) { \
    vassert(0, "Unexpected null pointer\n", NULL); \
  } else { \
    vassert(0, "Address %a not found in known segments\n", _addr); \
  } \
}

/*! \brief Wrapper around ::heap_info and ::static_info functions that
 * dispatches one of the above functions based on the type of supplied memory
 * address (`addr`) (static, global, tls or heap). For the case when the
 * supplied address does not belong to the track segments 0 is returned.
 *
 * \param uintptr_t addr - a memory address
 * \param char p - predicate type. See ::static_info for further details. */
static uintptr_t predicate(uintptr_t addr, char p) {
  TRY_SEGMENT(
    addr,
    return heap_info((uintptr_t)addr, p),
    return static_info((uintptr_t)addr, p));
  return 0;
}

/*! \brief Return a byte length of a memory block address `_addr` belongs to
 * \param uintptr_t _addr - a memory address */
#define block_length(_addr) predicate((uintptr_t)_addr, 'L')
/*! \brief Return a base address of a memory block address `_addr` belongs to
 * \param uintptr_t _addr - a memory address */
#define base_addr(_addr) predicate((uintptr_t)_addr, 'B')
/*! \brief Return a byte offset of a memory address given by `_addr` within
 * its block
 * \param uintptr_t _addr - a memory address */
#define offset(_addr) predicate((uintptr_t)_addr, 'O')
/* }}} */

/* Static allocation {{{ */

/** The below numbers identify offset "bases" for short block lengths.
 * An offset base is a number (a code) that represents the length of a
 * short block with a byte offset of `0`.
 * For instance, for a block of 4 bytes its offset base if 7, that is
 *  length 4, offset 0 => 7,
 *  length 4, offset 1 => 8,
 *  length 4, offset 2 => 9,
 *  length 4, offset 3 => 10,
 * and then for a block of 5 bytes its base offset if 11 etc. */
static const char short_offsets_base [] = { 0, 1, 2, 4, 7, 11, 16, 22, 29 };

/** Shadow masks for setting values of short blocks */
static const uint64_t short_shadow_masks[] = {
  0UL,
  4UL,
  3080UL,
  1578000UL,
  673456156UL,
  258640982060UL,
  92703853921344UL,
  31644393008028760UL,
  10415850140873816180UL
};

/*! \brief Record allocation of a given memory block and update shadows
 *  using offset-based encoding.
 *
 * \param ptr - pointer to a base memory address of the stack memory block.
 * \param size - size of the stack memory block. */
static void shadow_alloca(void *ptr, size_t size) {
  DVALIDATE_IS_ON_STATIC(ptr, size);
  unsigned char *prim_shadow = (unsigned char*)PRIMARY_SHADOW(ptr);
  uint64_t *prim_shadow_alt = (uint64_t *)PRIMARY_SHADOW(ptr);
  unsigned int *sec_shadow = (unsigned int*)SECONDARY_SHADOW(ptr);

  /* Make sure static region is nullified */
  DVALIDATE_NULLIFIED(prim_shadow, size);
  DVALIDATE_NULLIFIED(sec_shadow, size);

  /* Flip read-only bit for zero-size blocks. That is, physically it exists
   * but one cannot write to it. Further, the flipped read-only bit will also
   * identify such block as allocated */
  if (!size)
    setbit(READONLY_BIT, prim_shadow[0]);

  unsigned int i, j = 0, k = 0;
  if (IS_LONG_BLOCK(size)) { /* Long blocks */
    unsigned int i, j = 0, k = 0;
    int boundary = LONG_BLOCK_BOUNDARY(size);
    for (i = 0; i < boundary; i += LONG_BLOCK) {
      /* Set-up a secondary shadow segment */
      sec_shadow[j++] = size;
      sec_shadow[j++] = i;
      /* Set primary shadow offsets */
      prim_shadow_alt[k++] = LONG_BLOCK_MASK;
    }

    /* Write out the remainder */
    for (i = boundary; i < size; i++) {
      unsigned char offset = i%LONG_BLOCK + LONG_BLOCK_INDEX_START + LONG_BLOCK;
      prim_shadow[i] = (offset << 2);
    }
  } else { /* Short blocks */
    for (i = 0; i < size; i++) {
      unsigned char code = short_offsets_base[size] + i;
      prim_shadow[i] = (code << 2);
    }
  }
}
/* }}} */

/* Deletion of static blocks {{{ */

/*! \brief Nullifies shadow regions of a memory block given by its address.
 * \param ptr - base memory address of the stack memory block. */
static void shadow_freea(void *ptr) {
  DVALIDATE_STATIC_LOCATION(ptr);
  DASSERT(ptr == (void*)base_addr(ptr));
  size_t size = block_length(ptr);
  memset((void*)PRIMARY_SHADOW(ptr), 0, size);
  memset((void*)SECONDARY_SHADOW(ptr), 0, size);
}
/* }}} */

/* Static querying {{{ */

/*! \brief Return a non-zero value if a memory region of length `size`
 * starting at address `addr` belongs to a tracked stack, tls or
 * global memory block and 0 otherwise.
 * This function is only safe if applied to a tls, stack or global address. */
static int static_allocated(uintptr_t addr, long size) {
  unsigned char *prim_shadow = (unsigned char*)PRIMARY_SHADOW(addr);
  /* Unless the address belongs to tracked allocation 0 is returned */
  if (prim_shadow[0]) {
    unsigned int code = (prim_shadow[0] >> 2);
    unsigned int long_block = (code >= LONG_BLOCK_INDEX_START);
    size_t length, offset;
    if (long_block) {
      offset = code - LONG_BLOCK_INDEX_START;
      unsigned int *sec_shadow =
        (unsigned int*)SECONDARY_SHADOW(addr - offset) ;
      length = sec_shadow[0];
      offset = sec_shadow[1] + offset;
    } else {
      offset = short_offsets[code];
      length = short_lengths[code];
    }
    return offset + size <= length;
  }
  return 0;
}

/*! \brief Return a non-zero value if a statically allocated memory block
 * starting at `addr` of length `size` is fully initialized (i.e., each of
 * its cells is initialized). */
static int static_initialized(uintptr_t addr, long size) {
  /* Return 0 right away if the address does not belong to
   * static allocation */
  if (!static_allocated(addr, size))
    return 0;
  DVALIDATE_STATIC_ACCESS(addr, size);

  int result = 1;
  uint64_t *shadow = (uint64_t*)PRIMARY_SHADOW(addr);
  while (size > 0) {
    int rem = (size >= ULONG_BYTES) ? ULONG_BYTES : size;
    uint64_t mask = static_init_masks[rem];
    size -= ULONG_BYTES;
    /* Note that most of the blocks checked for initialization will be smaller
    * than 64 bits, therefore in most cases it is more efficient to complete
    * the loop rather than do a test and return if the result is false */
    result = result && (((*shadow) & mask) == mask);
    shadow++;
  }
  return result;
}

/*! \brief Checking whether a globally allocated memory block containing an
 * address _addr has read-only access. Note, this is light checking that
 * relies on the fact that a single block cannot contain read/write and
 * read-only parts, that is to check whether the block has read-only access it
 * is sufficient to check any of its bytes. */
#define global_readonly(_addr) \
  checkbit(READONLY_BIT, (*(char*)PRIMARY_GLOBAL_SHADOW(addr)))

/*! \brief Querying information about a specific global or stack memory address
 * (based on the value of parameter `global'). The return value is interpreted
 * based on the second argument that specifies parameters of the query:
 *
 * - 'B' - return the base address of the memory block `addr` belongs to or `0`
 *     if `addr` lies outside of tracked allocation.
 * - 'O' - return the offset of `addr` within its memory block or `0`
 *     if `addr` lies outside of tracked allocation.
 * - 'L' - return the size in bytes of the memory block `addr` belongs to or `0`
 *     if `addr` lies outside of tracked allocation.
 *
 * NB: One should make sure that a given address if valid before querying.
 * That is, for the cases when addr does not refer to a valid memory address
 * belonging to static allocation the return value for this function is
 * unspecified. */
static uintptr_t static_info(uintptr_t addr, char type) {
  DVALIDATE_STATIC_LOCATION(addr);
  unsigned char *prim_shadow = (unsigned char*)PRIMARY_SHADOW(addr);

  /* Unless the address belongs to tracked allocation 0 is returned */
  if (prim_shadow[0]) {
    unsigned int code = (prim_shadow[0] >> 2);
    unsigned int long_block = (code >= LONG_BLOCK_INDEX_START);
    if (long_block) {
      unsigned int offset = code - LONG_BLOCK_INDEX_START;
      unsigned int *sec_shadow =
        (unsigned int*)SECONDARY_SHADOW(addr - offset) ;
      switch(type) {
        case 'B': /* Base address */
          return addr - offset - sec_shadow[1];
        case 'O': /* Offset */
          return sec_shadow[1] + offset;
        case 'L': /* Length */
          return sec_shadow[0];
        default:
          DASSERT(0 && "Unknown static query type");
      }
    } else {
      switch(type) {
        case 'B': /* Base address */
          return addr - short_offsets[code];
        case 'O': /* Offset */
          return short_offsets[code];
        case 'L': /* Length */
          return short_lengths[code];
        default:
          DASSERT(0 && "Unknown static query type");
      }
    }
  }
  return 0;
}
/* }}} */

/* Static initialization {{{ */
/*! \brief The following function marks n bytes starting from the address
 * given by addr as initialized. `size` equating to zero indicates that the
 * whole block should be marked as initialized.  */
static void initialize_static_region(uintptr_t addr, long size) {
  DVALIDATE_STATIC_ACCESS(addr, size);
  DVASSERT(!(addr - base_addr(addr) + size > block_length(addr)),
    "Attempt to initialize %lu bytes past block boundaries\n"
    "starting at %a with block length %lu at base address %a\n",
    size, addr, block_length(addr), base_addr(addr));

  /* Below code marks `size` bytes following `addr` in the stack shadow as
   * initialized. That is, least significant bits of all 9 bytes following
   * `addr` should be flipped to ones. While this is a common pattern in this
   * program, here are some explanations.
   *
   * Here we grab a shadow region and initialize 8 (::ULONG_SIZE) bits at a
   * time using masks stored in ::static_init_masks. This few lines below are
   * better explained using an example. Let's say we need to mark 9 bytes as
   * initialized starting from some address `addr`.
   *
   * In order to do that we first grab a shadow region storing it in `shadow`.
   * For the first 8 bytes we grab a mask stored at ::static_init_masks[8]:
   *   `10000000 10000000 10000000 10000000 10000000 10000000 10000000 10000000`
   * That is, `*shadow |= static_init_masks[8]` sets 8 lowest significant bits
   * of the 8 bytes following *shadow to ones.
   *
   * After that we need to mark the remaining 1 bite as initialized. For that
   * we grab mask ::static_init_masks[1]:
   *  `10000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000`
   * That is, `*shadow |= static_init_masks[1]` will set only the least
   * significant bit in *shadow. */

  uint64_t *shadow = (uint64_t*)PRIMARY_SHADOW(addr);
  while (size > 0) {
    int rem = (size >= ULONG_BYTES) ? ULONG_BYTES : size;
    size -= ULONG_BYTES;
    *shadow |= static_init_masks[rem];
    shadow++;
  }
}
/* }}} */

/* Read-only {{{ */
/*! \brief Mark n bytes starting from the address given by `ptr` as initialized.
 * NOTE: This function has many similarities with ::initialize_static_region
 * The functionality, however is preferred to be kept separate
 * because the ::mark_readonly should operate only on the global shadow. */
static void mark_readonly (uintptr_t addr, long size) {
  /* Since read-only blocks can only be stored in the globals  segments (e.g.,
   * TEXT), this function required ptr carry a global address. */
  DASSERT(IS_ON_GLOBAL(addr));
  DASSERT(static_allocated(addr, 1));
  DVASSERT(!(addr - base_addr(addr) + size > block_length(addr)),
    "Attempt to mark read-only %lu bytes past block boundaries\n"
    "starting at %a with block length %lu at base address %a\n",
    size, addr, block_length(addr), base_addr(addr));

  /* See comments in ::initialize_static_region for details */
  uint64_t *shadow = (uint64_t*)PRIMARY_GLOBAL_SHADOW(addr);
  while (size > 0) {
    int rem = (size >= ULONG_BYTES) ? ULONG_BYTES : size;
    size -= ULONG_BYTES;
    *shadow |= static_readonly_masks[rem];
    shadow++;
  }
}
/* }}} */

/* Track program arguments (ARGC/ARGV) {{{ */
static void argv_alloca(int argc,  char ** argv) {
  /* Track a top-level container (i.e., `*argv`) */
  shadow_alloca(argv, (argc + 1)*sizeof(char*));
  initialize_static_region((uintptr_t)argv, (argc + 1)*sizeof(char*));
  /* Track argument strings */
  while (*argv) {
    size_t arglen = strlen(*argv) + 1;
    shadow_alloca(*argv, arglen);
    initialize_static_region((uintptr_t)*argv, arglen);
    argv++;
  }
}
/* }}} */

/* Heap allocation {{{ (malloc/calloc) */

/*! \brief Amount of heap memory allocated by the program.
 * Variable visible externally. */
static size_t heap_allocation_size = 0;

/*! \brief Create a heap shadow for an allocated memory block starting at `ptr`
 * and of length `size`. Optionally mark it as initialized if `init`
 * evaluates to a non-zero value.
 * \b NOTE: This function assumes that `ptr` is a valid base address of a
 * heap-allocated memory block, such that HEAP_SEGMENT bytes preceding `ptr`
 * correspond to `unusable space`.
 * \b WARNING: Current implementation assumes that the size of a heap segment
 * does not exceed 64 bytes. */
static void set_heap_segment(void *ptr, size_t size, size_t alloc_size, size_t init) {
  /* Ensure the shadowed block in on the tracked heap portion */
  DVALIDATE_IS_ON_HEAP(((uintptr_t)ptr) - HEAP_SEGMENT, size);
  DVALIDATE_ALIGNMENT(ptr); /* Make sure alignment is right */
  heap_allocation_size += size; /* Adjust tracked allocation size */

  /* Get aligned size of the block, i.e., an actual size of the
   * allocated block */
  unsigned char *shadow = (unsigned char*)HEAP_SHADOW(ptr);

  /* Make sure shadow is nullified before setting it */
  DVALIDATE_NULLIFIED(shadow, alloc_size);

  /* The overall number of block segments in a tracked memory block  */
  size_t segments = alloc_size/HEAP_SEGMENT;
  uintptr_t *segment = (uintptr_t*)(shadow);
  segment[1] = size;

  int i;
  /* Write the offsets per segment */
  for (i = 0; i < segments; i++) {
    segment = (uintptr_t*)(shadow + i*HEAP_SEGMENT);
    *segment = (uintptr_t)ptr;
  }

  /* If init is a non-zero value then mark all allocated bytes as initialized */
  if (init) {
    memset(HEAP_INIT_SHADOW(ptr), (unsigned int)ONE, alloc_size/8);
  }
}

/*! \brief Replacement for a malloc function that additionally tracks the
 * allocated memory block.
 *
 * NOTE: This malloc returns a `NULL` pointer if the requested size is `0`.
 * Such behaviour is compliant with the C99 standard, however it differs from
 * the behaviour of the GLIBC malloc, which returns a zero-size block instead.
 * The standard indicates that a return value for a zero-sized allocation
 * is implementation specific:
 *    "If the size of the space requested is zero, the behaviour is
 *    implementation-defined: either a null pointer is returned, or the
 *    behaviour is as if the size were some non-zero value, except that the
 *    returned pointer shall not be used to access an object." */
static void* shadow_malloc(size_t size) {
  size_t alloc_size = ALLOC_SIZE(size);

  /* Return NULL if the size is too large to be aligned */
  char* res = alloc_size ?
    (char*)native_aligned_alloc(HEAP_SEGMENT, alloc_size) : NULL;

  if (res)
    set_heap_segment(res, size, alloc_size, 0);

  return res;
}

/*! \brief  Replacement for `calloc` that enables memory tracking */
static void* shadow_calloc(size_t nmemb, size_t size) {
  /* Since both `nmemb` and `size` are both of size `size_t` the multiplication
   * of the arguments (which gives the actual allocation size) might lead to an
   * integer overflow. The below code checks for an overflow and sets the
   * `alloc_size` (argument a memory allocation function) to zero. */
  size = (size && nmemb > SIZE_MAX/size) ? 0 : nmemb*size;

  size_t alloc_size = ALLOC_SIZE(size);

  /* Since aligned size is required by the model do the allocation through
   * `malloc` and nullify the memory space by hand */
  char* res = size ? (char*)native_malloc(alloc_size) : NULL;

  if (res) {
    memset(res, 0, size);
    set_heap_segment(res, size, alloc_size, 1);
  }

  return res;
}
/* }}} */

/* Heap deallocation (free) {{{ */

/*! \brief Remove a memory block with base address given by `ptr` from tracking.
 * This function effectively nullifies block shadow tracking an application
 * block and optionally nullifies an init shadow associated with the block. */
static void unset_heap_segment(void *ptr, int init) {
  /* Base address of block shadow segment */
  uintptr_t *shadow = (uintptr_t*)HEAP_SHADOW(ptr);
  /* Base address of shadow block */
  uintptr_t *block_shadow = (uintptr_t*)HEAP_SHADOW(*shadow);
  /* Physical allocation size */
  size_t alloc_size = ALLOC_SIZE(block_shadow[1]);
  /* Actual block length */
  size_t length = block_shadow[1];
  /* Nullify shadow block */
  memset(block_shadow, ZERO, alloc_size);
  /* Adjust tracked allocation size */
  heap_allocation_size -= length;

  /* Nullify init shadow */
  if (init) {
    memset(HEAP_INIT_SHADOW(ptr), 0, alloc_size/8);
  }
}

/*! \brief Replacement for `free` with memory tracking  */
static void shadow_free(void *ptr) {
  if (ptr != NULL) { /* NULL is a valid behaviour */
    if (freeable(ptr)) {
      unset_heap_segment(ptr, 1);
    } else {
      vabort("Not a start of block (%a) in free\n", ptr);
    }
  }
}
/* }}} */

/* Heap reallocation (realloc) {{{ */
static void* shadow_realloc(void *ptr, size_t size) {
  char *res = NULL; /* Resulting pointer */
  /* If the pointer is NULL then realloc is equivalent to malloc(size) */
  if (ptr == NULL)
    return shadow_malloc(size);
  /* If the pointer is not NULL and the size is zero then realloc is
   * equivalent to free(ptr) */
  else if (ptr != NULL && size == 0) {
    shadow_free(ptr);
  } else {
    if (freeable(ptr)) { /* ... and valid for free  */
      size_t alloc_size = ALLOC_SIZE(size);
      res = native_realloc(ptr, alloc_size);
      DVALIDATE_ALIGNMENT(res);

      /* realloc succeeds, otherwise nothing needs to be done */
      if (res != NULL) {
        size_t alloc_size = ALLOC_SIZE(size);
        size_t old_size = block_length(ptr);
        size_t old_alloc_size = ALLOC_SIZE(old_size);

        /* Nullify old representation */
        unset_heap_segment(ptr, 0);

        /* Set up new block shadow */
        set_heap_segment(res, size, alloc_size, 0);

        /* Move init shadow */
        unsigned char* old_init_shadow  = (unsigned char*)HEAP_INIT_SHADOW(ptr);
        unsigned char* new_init_shadow  = (unsigned char*)HEAP_INIT_SHADOW(res);

        /* If realloc truncates allocation in the old init shadow it is first
         * needed to clear the old init shadow from the boundary of the old
         * shadow block to the size of the new allocation */
        if (old_size > size) {
          clearbits_right(
              old_alloc_size - size,
              old_init_shadow + old_alloc_size/8);
        }

        /* Now init shadow can be moved (if needed), keep in mind that
         * segment base addresses are aligned at a boundary of something
         * divisible by 8, so instead of moving actual bits here the
         * segments are moved to avoid dealing with bit-level operations
         * on incomplete bytes. */
        if (res != ptr) {
          size_t copy_size = (old_size > size) ? alloc_size : old_alloc_size;
          memcpy(new_init_shadow, old_init_shadow, copy_size);
          memset(old_init_shadow, 0, copy_size);
        }
      }
    } else {
      vabort("Not a start of block (%a) in realloc\n", ptr);
    }
  }
  return res;
}
/* }}} */

/* Heap aligned allocation (aligned_alloc) {{{ */
/*! \brief Replacement for `aligned_alloc` with memory tracking */
static void *shadow_aligned_alloc(size_t alignment, size_t size) {
  /* Check if:
   *  - size and alignment are greater than zero
   *  - alignment is a power of 2
   *  - size is a multiple of alignment */
  if (!size || !alignment || !powof2(alignment) || (size%alignment))
    return NULL;

  char *res = native_aligned_alloc(alignment, size);
  if (res)
    set_heap_segment(res, size, ALLOC_SIZE(size), 0);

  return (void*)res;
}
/* }}} */

/* Heap aligned allocation (posix_memalign) {{{ */
/*! \brief Replacement for `posix_memalign` with memory tracking */
static int shadow_posix_memalign(void **memptr, size_t alignment, size_t size) {
 /* Check if:
   *  - size and alignment are greater than zero
   *  - alignment is a power of 2 and a multiple of sizeof(void*) */
  if (!size || !alignment || !powof2(alignment) || alignment%sizeof(void*))
    return -1;

  /* Make sure that the first argument to posix memalign is indeed allocated */
  vassert(valid(memptr, sizeof(void*)),
      "\\invalid memptr in  posix_memalign", NULL);

  int res = native_posix_memalign(memptr, alignment, size);
  if (!res) {
    set_heap_segment(*memptr, size, ALLOC_SIZE(size), 0);
  }
  return res;
}
/* }}} */

/* Heap querying {{{ */
/*! \brief Return a non-zero value if a memory region of length `size`
 * starting at address `addr` belongs to an allocated (tracked) heap memory
 * block and a 0 otherwise. Note, this function is only safe if applied to a
 * heap address. */
static int heap_allocated(uintptr_t addr, size_t size) { /* + */
  /* Base address of the shadow segment the address belongs to */
  uintptr_t *shadow = (uintptr_t*)HEAP_SHADOW(addr - addr%HEAP_SEGMENT);

  /* Non-zero if the segment belongs to heap allocation */
  if (shadow[0]) {
    uintptr_t *first_segment = (uintptr_t*)HEAP_SHADOW(shadow[0]);
    /* shadow[0] - base address of the tracked block
     * fist_segment[1] - length (i.e., location in the first segment
     *  after base address)
     * offset is the difference between the address and base address (shadow[0])
     * Then an address belongs to heap allocation if
     *  offset + size <= length */
    return (addr - shadow[0]) + size <= first_segment[1];
  }
  return 0;
}

/*! \brief  Return a non-zero value if a given address is a base address of a
 * heap-allocated memory block that `addr` belongs to.
 *
 * As some of the other functions, \b \\freeable can be expressed using
 * ::IS_ON_HEAP, ::heap_allocated and ::base_addr. Here direct
 * implementation is preferred for performance reasons. */
static int freeable(void *ptr) { /* + */
  uintptr_t addr = (uintptr_t)ptr;
  if (!IS_ON_HEAP(addr))
    return 0;

  /* Address of the shadow segment the address belongs to */
  uintptr_t *shadow = (uintptr_t*)HEAP_SHADOW(addr - addr%HEAP_SEGMENT);
  /* Non-zero if the segment belongs to heap allocation */
  if (*shadow) {
    /* Block is freeable if `addr` is the base address of its block  */
    return (uintptr_t)*shadow == addr;
  }
  return 0;
}

/*! \brief Querying information about a specific heap memory address.
 * This function is similar to ::static_info except it returns data
 * associated with heap-allocated memory.
 * See in-line documentation for ::static_info for further details. */
static uintptr_t heap_info(uintptr_t addr, char type) { /* + */
  DVALIDATE_HEAP_ACCESS(addr, 1);
  /* Base address of the shadow segment the address belongs to.
   * First `sizeof(void*)` bytes of each segment store application-level
   * base address of the tracked block */
  uintptr_t *shadow = (uintptr_t*)HEAP_SHADOW(addr - addr%HEAP_SEGMENT);

  switch(type) {
    case 'B': /* Base address */
      return *shadow;
    case 'L': { /* Block length */
      /* Pointer to the first-segment in the shadow block */
      uintptr_t *segment = (uintptr_t*)HEAP_SHADOW(*shadow);
      /* Length of the stored block is stored in `sizeof(void*)` bytes
       * following the base address */
      return segment[1];
    }
    case 'O':
      /* Offset of a given address within its block. Difference between
       * input address and the base address of the block. */
      return addr - *shadow;
    default:
      DASSERT(0 && "Unknown heap query type");
  }
  return 0;
}
/*! \brief Implementation of the \b \\initialized predicate for heap-allocated
 * memory. NB: If `addr` does not belong to a valid heap region this function
 * returns 0. */
static int heap_initialized(uintptr_t addr, long len) {
  /* Base address of a shadow segment addr belongs to */
  unsigned char *shadow = (unsigned char*)(HEAP_INIT_SHADOW(addr));

  /* See comments in the `initialize_heap_region` function for more details */
  unsigned skip = (addr - HEAP_START)%8;
  unsigned set;
  if (skip) {
    set = 8 - skip;
    set = (len > set) ? set : len;
    len -= set;
    unsigned char mask = 0;
    setbits64_skip(set,mask,skip);

    if (*shadow != mask)
      return 0;
  }
  if (len > 0)
    return checkbits(len,shadow);
  return 1;
}

/* }}} */

/* Heap initialization {{{ */
/*! \brief Mark n bytes on the heap starting from address addr as initialized */
static void initialize_heap_region(uintptr_t addr, long len) {
  DVALIDATE_HEAP_ACCESS(addr, len);
  DVASSERT(!(addr - base_addr(addr) + len > block_length(addr)),
    "Attempt to initialize %lu bytes past block boundaries\n"
    "starting at %a with block length %lu at base address %a\n",
    len, addr, block_length(addr), base_addr(addr));

  /* Address within init shadow tracking initialization  */
  unsigned char *shadow = (unsigned char*)(HEAP_INIT_SHADOW(addr));

  /* First check whether the address in the init shadow is divisible by 8
   * (i.e., located on a byte boundary) */
  /* Leading bits in `*shadow` byte which do not need to be set
   * (i.e., skipped) */
  short skip = (addr - HEAP_START)%8;
  if (skip) {
    /* The remaining bits in the shadow byte */
    short set = 8 - skip;
    /* The length of initialized region can be short (shorter then the
     * above remainder). Adjust the number of bits to set accordingly. */
    set = (len > set) ? set : len;
    len -= set;
    setbits64_skip(set, *shadow, skip);
    /* Move to the next location if there are more bits to set */
    shadow++;
  }

  if (len > 0) {
    /* Set the remaining bits. Note `shadow` is now aligned at a byte
     * boundary, thus one can set `len` bits starting with address given by
     * `shadow` */
    setbits(len, shadow);
  }
}
/* }}} */

/* Any initialization {{{ */
/*! \brief Initialize a chunk of memory given by its start address (`addr`)
 * and byte length (`n`). */
static void initialize(void *ptr, size_t n) {
  TRY_SEGMENT(
    (uintptr_t)ptr,
    initialize_heap_region((uintptr_t)ptr, n),
    initialize_static_region((uintptr_t)ptr, n)
  )
}
/* }}} */

/* Internal state print (debug mode) {{{ */
#ifdef E_ACSL_DEBUG
/* ! \brief Print human-readable representation of a byte in a primary
 * shadow */
static void printbyte(unsigned char c, char buf[]) {
  if (c >> 2 < LONG_BLOCK_INDEX_START) {
    sprintf(buf, "PRIMARY: I{%u} RO{%u} OF{%2u} => %u[%u]",
      checkbit(INIT_BIT,c), checkbit(READONLY_BIT,c), c >> 2,
      short_lengths[c >> 2], short_offsets[c >> 2]);
  } else {
    sprintf(buf, "SECONDARY:  I{%u} RO{%u} OF{%u} => %4u",
      checkbit(INIT_BIT,c), checkbit(READONLY_BIT,c),
      (c >> 2), (c >> 2) - LONG_BLOCK_INDEX_START);
  }
}

/*! \brief Print human-readable (well, ish) representation of a memory block
 * using primary and secondary shadows. */
static void print_static_shadows(uintptr_t addr, size_t size) {
  char prim_buf[256];
  char sec_buf[256];

  unsigned char *prim_shadow = (unsigned char*)PRIMARY_SHADOW(addr);
  unsigned int *sec_shadow = (unsigned int*)SECONDARY_SHADOW(addr);

  int i, j = 0;
  for (i = 0; i < size; i++) {
    sec_buf[0] = '\0';
    printbyte(prim_shadow[i], prim_buf);
    if (IS_LONG_BLOCK(size) && (i%LONG_BLOCK) == 0) {
      j += 2;
      if (i < LONG_BLOCK_BOUNDARY(size)) {
        sprintf(sec_buf, " %a  SZ{%u} OF{%u}",
          &sec_shadow[j], sec_shadow[j-2], sec_shadow[j-1]);
      }
      if (i) {
        DLOG("---------------------------------------------\n");
      }
    }
    DLOG("| [%2d] %a | %s || %s\n", i, &prim_shadow[i], prim_buf, sec_buf);
  }
}

/*! \brief Print human-readable representation of a heap shadow region for a
 * memory block of length `size` starting at address `addr`.  */
static void print_heap_shadows(uintptr_t addr, size_t size) {
  unsigned char *block_shadow = (unsigned char*)HEAP_SHADOW(addr);
  unsigned char *init_shadow =  (unsigned char*)HEAP_INIT_SHADOW(addr);

  size_t alloc_size = ALLOC_SIZE(size);
  size_t segments = alloc_size/HEAP_SEGMENT;
  uintptr_t *segment = (uintptr_t*)(block_shadow);

  DLOG(" | === Block Shadow ======================================\n");
  DLOG(" | Access addr:  %a\n", addr);
  DLOG(" | Block Shadow: %a\n",	 block_shadow);
  DLOG(" | Init	 Shadow: %a\n",	 init_shadow);
  DLOG(" | Segments:     %lu\n", segments);
  DLOG(" | Aligned size: %lu bytes\n", alloc_size);

  if (zeroed_out(block_shadow, alloc_size))
    DLOG(" | << Nullified >>  \n");

  DLOG(" | Actual size:  %lu bytes\n", segment[1]);

  size_t i;
  for (i = 0; i < segments; i++) {
    segment = (uintptr_t*)(block_shadow + i*HEAP_SEGMENT);
    DLOG(" |   Segment: %lu, Base: %a \n", i, *segment);
  }

  if (zeroed_out(init_shadow, alloc_size/8))
    DLOG(" | << Nullified >>  \n");

  DLOG(" | Initialization: \n |   ");
  for (i = 0; i < alloc_size/8 + 8; i++) {
    if (i > 0 && (i*8)%HEAP_SEGMENT == 0)
      DLOG("\n |   ");

    DLOG("%8b ", init_shadow[i], init_shadow[i]);
  }
  DLOG("\n");
}

static void print_shadows(uintptr_t addr, size_t size) {
  if (IS_ON_STATIC(addr))
    print_static_shadows(addr, size);
  else if (IS_ON_HEAP(addr))
    print_heap_shadows(addr, size);
}

static void print_memory_segment(struct memory_segment *seg, const char *name) {
  DLOG(" --- %s ------------------------------------------\n", name);
  DLOG("%s Size:                      %16lu MB\n", name, MB_SZ(seg->size));
  DLOG("%s Start:                     %19lu\n", name, seg->start);
  DLOG("%s End:                       %19lu\n", name, seg->end);

  DLOG("%s Primary Shadow Offset:     %19lu\n", name, seg->prim_offset);
  DLOG("%s Primary Shadow Size:       %16lu MB\n", name, MB_SZ(seg->prim_size));
  DLOG("%s Primary Shadow Start:      %19lu\n", name, seg->prim_start);
  DLOG("%s Primary Shadow End:        %19lu\n", name, seg->prim_end);

  DLOG("%s Secondary Shadow Offset:   %19lu\n", name, seg->sec_offset);
  DLOG("%s Secondary Shadow Size:     %16lu MB\n", name, MB_SZ(seg->sec_size));
  DLOG("%s Secondary Shadow Start:    %19lu\n", name, seg->sec_start);
  DLOG("%s Secondary Shadow End:      %19lu\n", name, seg->sec_end);
}

static void print_memory_layout() {
  print_memory_segment(&mem_layout.heap, "Heap");
  print_memory_segment(&mem_layout.stack, "Stack");
  print_memory_segment(&mem_layout.global, "Global");
  print_memory_segment(&mem_layout.tls, "TLS");
  DLOG("-----------------------------------------------------\n");
}

/*! \brief Output the shadow segment the address belongs to */
static const char* which_segment(uintptr_t addr) {
  const char *loc = NULL;
  if (IS_ON_STACK(addr))
    loc = "stack";
  else if (IS_ON_HEAP(addr))
    loc = "heap";
  else if (IS_ON_GLOBAL(addr))
    loc = "global";
  else if (IS_ON_TLS(addr))
    loc = "TLS";
  else
    loc = "untracked";
  return loc;
}

/* NOTE: Above functions are designed to be used only through the following
 * macros or debug functions included/defined based on the value of the
 * E_ACSL_DEBUG macro. */

/*! \brief Print program layout. This function outputs start/end addresses of
 * various program segments, their shadow counterparts and sizes of shadow
 * regions used. */
#define DEBUG_PRINT_LAYOUT print_memory_layout()
void ___e_acsl_debug_print_layout() { DEBUG_PRINT_LAYOUT; }

/*! \brief Print the shadow segment address addr belongs to */
#define DEBUG_PRINT_SEGMENT(_addr) which_segment(_addr)
void ___e_acsl_debug_print_segment(uintptr_t addr) { DEBUG_PRINT_SEGMENT(addr); }

/*! \brief Print human-readable representation of a shadow region corresponding
 * to a memory address addr. The second argument (size) if the size of the
 * shadow region to be printed. Normally addr argument is a base address of a
 * memory block and size is its length. */
#define DEBUG_PRINT_SHADOW(addr, size) \
  print_shadows((uintptr_t)addr, (size_t)size)
void ___e_acsl_debug_print_shadow(uintptr_t addr, size_t size) {
  DEBUG_PRINT_SHADOW(addr, size);
}

#else
/* \cond exclude from doxygen */
#define DEBUG_PRINT_SHADOW(addr, size)
#define DEBUG_PRINT_LAYOUT
#define DEBUG_PRINT_SEGMENT(addr)
/* \endcond */
#endif
/* }}} */
