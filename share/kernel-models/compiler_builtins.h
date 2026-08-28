/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) CEA                                                     */
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

/* GCC exposes these aliases without requiring a system header. */
#if !defined(__int128_t) && defined(__GNUC__)
typedef __int128 __int128_t;
#define __int128_t __int128_t
#endif

#if !defined(__uint128_t) && defined(__GNUC__)
typedef unsigned __int128 __uint128_t;
#define __uint128_t __uint128_t
#endif

/*
 * Frama-C does not yet retain GCC's __counted_by__ association between a
 * flexible array and its counter field.  Model __builtin_counted_by_ref with
 * its documented unannotated-array type so Linux's _Generic wrappers select
 * their no-counter fallback.  This is a front-end compatibility model: it
 * deliberately does not model a counter-field update for annotated arrays.
 */
/*@ assigns \nothing; */
void *__builtin_counted_by_ref(void *flexible_array);

/*
 * GCC permits the operands and destination of its generic overflow builtins
 * to have different integral types.  This first kernel model covers matching
 * int, long, and long long variants (signed and unsigned), which includes the
 * kernel's size_add(), size_sub(), and size_mul() helpers.  The prototypes
 * keep uses outside that supported set visible as type diagnostics.
 */

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (int)(a + b);
  ensures result_overflow: a + b == (int)(a + b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_sadd_overflow(int a, int b, int *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (long)(a + b);
  ensures result_overflow: a + b == (long)(a + b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_saddl_overflow(long a, long b, long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (long long)(a + b);
  ensures result_overflow: a + b == (long long)(a + b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_saddll_overflow(long long a, long long b, long long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned int)(a + b);
  ensures result_overflow: a + b == (unsigned int)(a + b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_uadd_overflow(unsigned int a, unsigned int b,
                              unsigned int *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned long)(a + b);
  ensures result_overflow: a + b == (unsigned long)(a + b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_uaddl_overflow(unsigned long a, unsigned long b,
                               unsigned long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned long long)(a + b);
  ensures result_overflow: a + b == (unsigned long long)(a + b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_uaddll_overflow(unsigned long long a, unsigned long long b,
                                unsigned long long *res);

#define __builtin_add_overflow(a, b, res) \
  _Generic((a),                           \
    int: __builtin_sadd_overflow,         \
    unsigned int: __builtin_uadd_overflow, \
    long: __builtin_saddl_overflow,       \
    unsigned long: __builtin_uaddl_overflow, \
    long long: __builtin_saddll_overflow, \
    unsigned long long: __builtin_uaddll_overflow \
  )(a, b, res)

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (int)(a - b);
  ensures result_overflow: a - b == (int)(a - b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_ssub_overflow(int a, int b, int *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (long)(a - b);
  ensures result_overflow: a - b == (long)(a - b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_ssubl_overflow(long a, long b, long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (long long)(a - b);
  ensures result_overflow: a - b == (long long)(a - b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_ssubll_overflow(long long a, long long b, long long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned int)(a - b);
  ensures result_overflow: a - b == (unsigned int)(a - b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_usub_overflow(unsigned int a, unsigned int b,
                              unsigned int *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned long)(a - b);
  ensures result_overflow: a - b == (unsigned long)(a - b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_usubl_overflow(unsigned long a, unsigned long b,
                               unsigned long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned long long)(a - b);
  ensures result_overflow: a - b == (unsigned long long)(a - b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_usubll_overflow(unsigned long long a, unsigned long long b,
                                unsigned long long *res);

#define __builtin_sub_overflow(a, b, res) \
  _Generic((a),                           \
    int: __builtin_ssub_overflow,         \
    unsigned int: __builtin_usub_overflow, \
    long: __builtin_ssubl_overflow,       \
    unsigned long: __builtin_usubl_overflow, \
    long long: __builtin_ssubll_overflow, \
    unsigned long long: __builtin_usubll_overflow \
  )(a, b, res)

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (int)(a * b);
  ensures result_overflow: a * b == (int)(a * b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_smul_overflow(int a, int b, int *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (long)(a * b);
  ensures result_overflow: a * b == (long)(a * b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_smull_overflow(long a, long b, long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (long long)(a * b);
  ensures result_overflow: a * b == (long long)(a * b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_smulll_overflow(long long a, long long b, long long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned int)(a * b);
  ensures result_overflow: a * b == (unsigned int)(a * b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_umul_overflow(unsigned int a, unsigned int b,
                              unsigned int *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned long)(a * b);
  ensures result_overflow: a * b == (unsigned long)(a * b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_umull_overflow(unsigned long a, unsigned long b,
                               unsigned long *res);

/*@
  requires valid_res: \valid(res);
  assigns \result, *res \from a, b;
  ensures initialization:res: \initialized(res);
  ensures res_wrapped: *res == (unsigned long long)(a * b);
  ensures result_overflow: a * b == (unsigned long long)(a * b) ? \result == 0 : \result == 1;
 */
_Bool __builtin_umulll_overflow(unsigned long long a, unsigned long long b,
                                unsigned long long *res);

#define __builtin_mul_overflow(a, b, res) \
  _Generic((a),                           \
    int: __builtin_smul_overflow,         \
    unsigned int: __builtin_umul_overflow, \
    long: __builtin_smull_overflow,       \
    unsigned long: __builtin_umull_overflow, \
    long long: __builtin_smulll_overflow, \
    unsigned long long: __builtin_umulll_overflow \
  )(a, b, res)

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
