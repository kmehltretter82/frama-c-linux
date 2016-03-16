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
/* Set a given bit in a number to '1'.
 * Example: bitset(7, x) changes 7th lowest bit of x to 1 */
#define bitset(_bit,_number) (_number |= 1 << _bit)

/* Same as bitset but the bit is set of 0 */
#define bitclear(_bit, _number) (_number &= ~(1 << _bit))

/* Evaluates to a true value if a given bit in a number is set to 1. */
#define bitcheck(_bit, _number) ((_number >> _bit) & 1)

/* Toggle a given bit. */
#define bittoggle(_bit, _number) (_number ^= 1 << _bit)

/* Set a given bit to a specified value (e.g., 0 or 1). */
#define bitchange(_bit, _val, _number) \
  (_number ^= (-_val ^ _number) & (1 << _bit))

/* Fill the first n + skip bits of the memory area pointed to by s with ones
 * (c != 0) or zeroes (c == 0).
 *
 * Example:
 *  let p1 be a pointer to  1111 1111 1111 1111 and
 *  p0 be a pointer to 0000 0000 0000 0000, then
 *
 *  bitwise_memset(p0, 4, 1, 0)
 *    1111 0000 0000 0000
 *  bitwise_memset(p1, 3, 0, 2)
 *    1100 0111 1111 1111
 *
 * NB: In the grand scheme of things it is convenient to have a function that
 * can set bits in a universal manner (such as the function below). On the other
 * hand for blocks smaller than 64 bits using integers may be a faster way of
 * dealing with bitwise operations. */
static void bitwise_memset(void *s, size_t n, int c, unsigned int skip) {
  char *p = (char*)s;

  if (skip) {
    p += (skip/8);
    skip = skip%8;

    if (skip) {
      int mask = 255;

      if (skip)
        mask = (mask << skip);
      if (n < 8 - skip)
        mask = mask & (255 >> (8 - skip - n));

      n = (n >= 8 - skip) ? n - 8 + skip : 0;

      if (c)
        p[0]  = p[0] | mask;
      else
        p[0]  = p[0] & (mask ^ 255);
      p++;
    }
  }

  if (n) {
    size_t bytes = n/8;
    if (bytes)
      memset(p, c ? 255 : 0, bytes);

    if (c)
      p[bytes]  = p[bytes] | (255 >> (8 - n%8));
    else
      p[bytes]  = p[bytes] & (255 << n%8);
  }
}

/* Same as bitwise_memset with skip parameter 0 but sets the bits from right
 * to left. Example:
 *  let p1 be a pointer to  1111 1111 1111 1111, then
 *    bitwise_memset_backwards(p1, 5, 0) will lead to
 *      1111 1111 1110 0000 */
static void bitwise_memset_backwards(void *s, size_t n, int c) {
  char *p = (char*)s;
  int bytes = n/8;
  p -= bytes;
  memset(p, c ? 255 : 0, bytes);
  p--;
  if (!c)
    p[0]  = p[0] & (255 >> n%8);
  else
    p[0]  = p[0] | (255 << (8 - n%8));
}
/* }}} */
#endif
