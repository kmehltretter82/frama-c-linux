/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) 2026 Frama-C Linux contributors                         */
/*                                                                        */
/**************************************************************************/

/*
 * Compiler builtins used by Linux headers which are safe to model without
 * depending on Frama-C's userspace libc headers.  This file is intended to
 * be force-included before a kernel translation unit.
 */

#ifndef __FC_LINUX_COMPILER_BUILTINS_H
#define __FC_LINUX_COMPILER_BUILTINS_H

/*@
  requires x_nonzero: x != 0;
  assigns \result \from indirect:x;
  ensures result_is_bit_count: 0 <= \result < 8 * sizeof(x);
 */
int __builtin_clz(unsigned int x);

/*@
  requires x_nonzero: x != 0;
  assigns \result \from indirect:x;
  ensures result_is_bit_count: 0 <= \result < 8 * sizeof(x);
 */
int __builtin_clzl(unsigned long x);

/*@
  requires x_nonzero: x != 0;
  assigns \result \from indirect:x;
  ensures result_is_bit_count: 0 <= \result < 8 * sizeof(x);
 */
int __builtin_clzll(unsigned long long x);

/*@
  requires x_nonzero: x != 0;
  assigns \result \from indirect:x;
  ensures result_is_bit_count: 0 <= \result < 8 * sizeof(x);
 */
int __builtin_ctz(unsigned int x);

/*@
  requires x_nonzero: x != 0;
  assigns \result \from indirect:x;
  ensures result_is_bit_count: 0 <= \result < 8 * sizeof(x);
 */
int __builtin_ctzl(unsigned long x);

/*@
  requires x_nonzero: x != 0;
  assigns \result \from indirect:x;
  ensures result_is_bit_count: 0 <= \result < 8 * sizeof(x);
 */
int __builtin_ctzll(unsigned long long x);

#endif
