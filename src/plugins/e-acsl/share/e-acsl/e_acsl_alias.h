/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2017                                               */
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
 * \file  e_acsl_alias.h
 *
 * \brief Function aliasing
***************************************************************************/

#ifndef E_ACSL_ALIAS
#define E_ACSL_ALIAS

/* Concatenation of 2 tokens */
# define preconcat(x,y) x ## y
# define concat(x,y) preconcat(x,y)
# define ext_prefix __e_acsl_
# define export_alias(_n) concat(public_prefix, _n)

/** Define `aliasname` as a strong alias for `name`. */
# define strong_alias(name, aliasname) _strong_alias(name, aliasname)
# define _strong_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((alias (#name)));

/** Define `aliasname` as a weak alias for `name`. */
# define weak_alias(name, aliasname) _weak_alias (name, aliasname)
# define _weak_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((weak, alias (#name)));

/** Prefix added to public functions of E-ACSL public API */
# define public_prefix __e_acsl_
/** Make a strong alias from some function named `f` to __e_acsl_f */
# define public_alias(f) strong_alias(f, concat(public_prefix,f))
/** Make a strong alias from some function named `f1` to __e_acsl_f2 */
# define public_alias2(f1,f2) strong_alias(f1, concat(public_prefix,f2))

#endif
