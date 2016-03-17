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

/* Bit-level manipulations and endianness checks.
 * Should be included after e_acsl_printf.h and e_acsl_string.h headers. */

#ifndef E_ACSL_BITS
#define E_ACSL_BITS

#include <stdint.h>

/* FIXME: Present implementation is built for little-endian byte order.  That
 * is, the implementation assumes that least significant bytes are stored at
 * the highest memory addresses. In future support for big-endian/PDP byte
 * orders should also be provided. */

/* Check if we have little-endian and abort the execution otherwise. */
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#  error "Big-endian byte order is unsupported"
#elif __BYTE_ORDER__ == __ORDER_PDP_ENDIAN__
#  error "PDP-endian byte order is unsupported"
#elif __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#  error "Unknown byte order"
#endif

/* Bit-level manipulations {{{ */

/* 64-bit type with all bits set to zeroes */
const uint64_t ZERO = 0;

/* 64-bit type with all bits set to ones */
const uint64_t ONE  = ~0;

/* Set a given bit in a number to '1'.
 * Example: bitset(7, x) changes 7th lowest bit of x to 1 */
#define setbit(_bit,_number) (_number |= 1 << _bit)

/* Same as bitset but the bit is set of 0 */
#define clearbit(_bit, _number) (_number &= ~(1 << _bit))

/* Evaluates to a true value if a given bit in a number is set to 1. */
#define checkbit(_bit, _number) ((_number >> _bit) & 1)

/* Toggle a given bit. */
#define togglebit(_bit, _number) (_number ^= 1 << _bit)

/* Set a given bit to a specified value (e.g., 0 or 1). */
#define changebit(_bit, _val, _number) \
  (_number ^= (-_val ^ _number) & (1 << _bit))

/* Set up to 64-bit in given number (from the left)
 * Example: setbits64(x, 7) sets first 7 bits in x to ones */
#define setbits64(_number, _bits)   (_number |= ~(ONE << _bits))

/* Same as setbits64 but clears bits (sets to zeroes) */
#define clearbits64(_number, _bits) (_number &= ONE << _bits)

/* Assume _number is a 64-bit number and sets _bits from the right to ones
 * Example: let x is a 64-bit zero, then setbits64(x, 7) will yield:
 *   00000000 00000000 00000000 00000000 00000000 00000000 00000000 01111111 */
#define setbits64_right(_number, _bits)   (_number |= ~(ONE >> _bits))

/* Same as setbits64_right but clears bits (sets to zeroes) */
#define clearbits64_right(_number, _bits) (_number &= ONE >> _bits)

void setbits(void *ptr, size_t size) {
  size_t i;
  int64_t *lp = (int64_t*)ptr;
  for (i = 0; i < size/64; i++)
    *(lp+i) |= ONE;
  setbits64(*(lp+i), size%64);
}

void clearbits(void *ptr, size_t size) {
  size_t i;
  int64_t *lp = (int64_t*)ptr;
  for (i = 0; i < size/64; i++)
    *(lp+i) &= ZERO;
  clearbits64(*(lp+i), size%64);
}
/* }}} */
#endif