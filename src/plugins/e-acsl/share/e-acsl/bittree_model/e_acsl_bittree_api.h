/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2016                                               */
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
 * \file  e_acsl_bittree_api.h
 * \brief Patricia Trie API
***************************************************************************/

#ifndef E_ACSL_BITTREE_API
#define E_ACSL_BITTREE_API

#include "stdlib.h"
#include "stdbool.h"

/*! \brief Structure representing an allocated memory block */
struct _block {
  size_t ptr;  //!< Base address
  size_t size; //!< Block length (in bytes)
  unsigned char * init_ptr; //!< Per-bit initialization
  size_t init_cpt; //!< Number of initialized bytes
  _Bool is_readonly; //!< True if a block is marked read-only
  _Bool freeable; //!< True if a block can be de-allocated using `free`
};

/*! \brief Remove a block from the structure */
static void bt_remove(struct _block *b);

/*! \brief Add a block to the structure */
static void bt_insert(struct _block *b);

/*! \brief Return block B such that: `\base_addr(B->ptr) == ptr`.
NB: The function assumes that such a block exists. */
static struct _block * bt_lookup(void *ptr);

/*! \brief Return block B such that:
   `\base_addr(B->ptr) <= ptr < (\base_addr(B->ptr) + size)`
   or NULL if such a block does not exist. */
static struct _block * bt_find(void *ptr);

/*! \brief Erase the contents of the structure */
static void bt_clean(void);

/*! \brief Print information about a given block */
static void bt_print_block(struct _block *b);

/*! \brief Erase information about a block's initialization */
static void bt_clean_block_init(struct _block *b);

/*! \brief Erase all information about a given block */
static void bt_clean_block(struct _block *b);
#endif
