/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2014                                               */
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

#include "e_acsl_mmodel_api.h"
#include "e_acsl_mmodel.h"
#include "stdio.h"

struct _node {
  struct _block * value;
  struct _node * next;
};

struct _node * __list = NULL;


void __remove_element(struct _block* ptr) {
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


void __add_element(struct _block* ptr) {
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


struct _block* __get_exact(void* ptr) {
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


struct _block* __get_cont(void* ptr) {
  struct _node * tmp = __list;
  for(; tmp != NULL; tmp = tmp->next) {
    if(tmp->value->ptr <= (size_t)ptr
       && (size_t)ptr < tmp->value->ptr + tmp->value->size)
      return tmp->value;
    else if(tmp->value->ptr > (size_t)ptr)
      break;
  }
  return NULL;
}


void __clean_struct() {
  struct _node * next;
  for(; __list != NULL ;) {
    __clean_block(__list->value);
    next = __list->next;
    free(__list);
    __list = next;
  }
}


void __debug_struct() {
  struct _node * tmp = __list;
  printf("\t\t\t------------DEBUG\n");
  for(; tmp != NULL; tmp = tmp->next) {
    printf("\t\t\t");
    __print_block(tmp->value);
  }
  printf("\t\t\t-----------------\n");
}

