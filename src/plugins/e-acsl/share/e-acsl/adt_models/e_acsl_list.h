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

#ifndef E_ACSL_LIST
#define E_ACSL_LIST

#include "e_acsl_syscall.h"
#include "e_acsl_printf.h"
#include "e_acsl_assert.h"
#include "e_acsl_adt_api.h"

struct _node {
  struct _block * value;
  struct _node * next;
};

static struct _node * __list = NULL;

static void __remove_element(struct _block* ptr) {
  struct _node * tmp1 = __list, * tmp2;
  if(tmp1 == NULL) return;
  tmp2 = tmp1->next;

  /* first element */
  if(tmp1->value->ptr == ptr->ptr) {
    __list = tmp1->next;
    free(tmp1);
  }

  for(; tmp2 != NULL && tmp2->value->ptr < ptr->ptr;) {
    tmp1 = tmp2;
    tmp2 = tmp2->next;
  }
  if(tmp2 == NULL) return;
  if(tmp2->value->ptr == ptr->ptr) {
    tmp1->next = tmp2->next;
    free(tmp2);
  }
}


static void __add_element(struct _block* ptr) {
  struct _node * tmp1 = __list, * tmp2, * new;
  new = malloc(sizeof(struct _node));
  if(new == NULL) return;
  new->value = ptr;
  new->next = NULL;

  if(__list == NULL) {
    __list = new;
    return;
  }
  if(__list->value->ptr >= ptr->ptr) {
    new->next = __list;
    __list = new;
    return;
  }
  tmp2 = tmp1->next;

  for(; tmp2 != NULL && tmp2->value->ptr < ptr->ptr;) {
    tmp1 = tmp2;
    tmp2 = tmp2->next;
  }

  tmp1->next = new;
  new->next = tmp2;
}


static struct _block* __get_exact(void* ptr) {
  struct _node * tmp = __list;
  for(; tmp != NULL;) {
    if(tmp->value->ptr == (size_t)ptr)
      return tmp->value;
    if(tmp->value->ptr > (size_t)ptr)
      break;
    tmp = tmp->next;
  }
  return NULL;
}


static struct _block* __get_cont(void* ptr) {
  struct _node * tmp = __list;
  for(; tmp != NULL; tmp = tmp->next) {
    if(tmp->value->ptr > (size_t)ptr)
      break;
    if(tmp->value->size == 0 && (size_t)ptr == tmp->value->ptr)
      return tmp->value;
    if((size_t)ptr < tmp->value->ptr + tmp->value->size)
      return tmp->value;
  }
  return NULL;
}


static void __clean_struct() {
  struct _node * next;
  for(; __list != NULL ;) {
    __clean_block(__list->value);
    next = __list->next;
    free(__list);
    __list = next;
  }
}

/*********************/
/* DEBUG             */
/*********************/
#ifdef E_ACSL_DEBUG
void __e_acsl_debug_struct() {
  struct _node * tmp = __list;
  DLOG("\t\t\t------------DEBUG\n");
  for(; tmp != NULL; tmp = tmp->next) {
    DLOG("\t\t\t");
    __e_acsl_print_block(tmp->value);
  }
  DLOG("\t\t\t-----------------\n");
}

#endif
#endif
