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

/* Memory block allocated and may be deallocated */
struct _block {
  size_t ptr;	/* base address */
  size_t size;	/* block length */
/* Keep trace of initialized sub-blocks within a memory block */
  unsigned char * init_ptr; /* dynamic array of booleans */
  size_t init_cpt;
  _Bool is_readonly;
  _Bool freeable;
};

/* remove the block from the structure */
static void remove_element(struct _block *);

/* add a block in the structure */
static void add_element(struct _block *);

/* return the block B such as : begin addr of B == ptr
   we suppose that such a block exists, but we could return NULL if not */
static struct _block * get_exact(void *);

/* return the block B containing ptr, such as :
   begin addr of B <= ptr < (begin addr + size) of B
   or NULL if such a block does not exist */
static struct _block * get_cont(void *);

/* erase the content of the structure */
static void clean_struct(void);

/* print the information about a block */
static void print_block(struct _block * ptr );

/* erase information about initialization of a block */
static void clean_init(struct _block * ptr );

/* erase all information about a block */
static void clean_block(struct _block * ptr);
#endif
