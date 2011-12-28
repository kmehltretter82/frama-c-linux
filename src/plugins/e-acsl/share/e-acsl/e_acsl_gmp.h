/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012                                                    */
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

/******************/
/* GMP prototypes */
/******************/

/****************/
/* Initializers */
/****************/

/*@ ensures \valid(x);
  @ assigns *x; */
extern void __gmpz_init(mpz_t x);

/*@ requires \valid(z_orig);
  @ ensures \valid(z);
  @ assigns *z; */
extern void __gmpz_init_set(mpz_t z, const mpz_t z_orig);

/*@ ensures \valid(z);
  @ assigns *z \from n; */
extern void __gmpz_init_set_ui(mpz_t z, unsigned long int n);

/*@ ensures \valid(z);
  @ assigns *z \from n; */
extern void __gmpz_init_set_si(mpz_t z, signed long int n);

/*@ ensures \valid(z);
  @ assigns *z; */
extern int __gmpz_init_set_str(mpz_t z, const char *str, int base);

/***************/
/* Assignments */
/***************/

/*@ requires \valid(z_orig);
  @ requires \valid(z);
  @ assigns *z; */
extern void __gmpz_set(mpz_t z, const mpz_t z_orig);

/*@ requires \valid(z);
  @ assigns *z \from n; */
extern void __gmpz_set_ui(mpz_t z, unsigned long int n);

/*@ requires \valid(z);
  @ assigns *z \from n; */
extern void __gmpz_set_si(mpz_t z, signed long int n);

/*************/
/* Finalizer */
/*************/

/*@ requires \valid(x);
  @ assigns *x; */
extern void __gmpz_clear(mpz_t x);

/********************/
/* Logical operator */
/********************/

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns \nothing; */
extern int __gmpz_cmp(const mpz_t z1, const mpz_t z2);

/***********************/
/* Arithmetic operator */
/***********************/

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns *z1; */
extern int __gmpz_comp(mpz_t z1, const mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns *z1; */
extern void __gmpz_neg(mpz_t z1, const mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void __gmpz_add(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void __gmpz_sub(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void __gmpz_mul(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void __gmpz_tdiv_q(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void __gmpz_tdiv_r(mpz_t z1, const mpz_t z2, const mpz_t z3);

/************************/
/* Coercions to C types */
/************************/

/*@ requires \valid(z); 
  @ assigns \nothing; */
extern long __gmpz_get_si(const mpz_t z);

/*@ requires \valid(z); 
  @ assigns \nothing; */
extern unsigned long __gmpz_get_ui(const mpz_t z);
