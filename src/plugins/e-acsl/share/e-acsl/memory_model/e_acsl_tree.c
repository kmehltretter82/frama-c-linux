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
  struct _node * left, * right;
};

struct _node * __root = NULL;

void __remove_element(struct _block* ptr) {
  struct _node * tmp = __root, * father = NULL;

  while(tmp != NULL) {
    if(tmp->value->ptr > ptr->ptr) { father = tmp; tmp = tmp->left; }
    else if(tmp->value->ptr < ptr->ptr) { father = tmp; tmp = tmp->right; }
    else break;
  }
  if(tmp == NULL) return;

  if(tmp->left == NULL) {
    if(__root == tmp) __root = tmp->right;
    else {
      if(father->left == tmp) father->left = tmp->right;
      else father->right = tmp->right;
    }
    free(tmp);
  }
  else if(tmp->right == NULL) {
    if(__root == tmp) __root = tmp->left;
    else {
      if(father->left == tmp) father->left = tmp->left;
      else father->right = tmp->left;
    }
    free(tmp);
  }
  else { /* two children */
    struct _node * cursor = tmp->right;
    father = tmp;
    while(cursor->left != NULL) { father = cursor; cursor = cursor->left; }
    tmp->value = cursor->value;
    if(father->left == cursor) father->left = cursor->right;
    else father->right = cursor->right;
    free(cursor);
  }
}


void __add_element(struct _block* ptr) {
  enum {LEFT, RIGHT} pos;
  struct _node * new, * tmp = __root, * father = NULL;
  new = malloc(sizeof(struct _node));
  if(new == NULL) return;
  new->value = ptr;
  new->left = new->right = NULL;
  
  if(__root == NULL) {
    __root = new;
    return;
  }
  while(tmp != NULL) {
    father = tmp;
    if(tmp->value->ptr >= ptr->ptr) {
      tmp = tmp->left;
      pos = LEFT;
    }
    else {
      tmp = tmp->right;
      pos = RIGHT;
    }
  }
  if(pos == LEFT) father->left = new;
  else father->right = new;
}


struct _block* __get_exact(void* ptr) {
  struct _node * tmp = __root;
  while(tmp != NULL) {
    if(tmp->value->ptr > (size_t)ptr) tmp = tmp->left;
    else if(tmp->value->ptr < (size_t)ptr) tmp = tmp->right;
    else return tmp->value;
  }
  return NULL;
}


struct _block* _get_cont_rec(struct _node * node, void* ptr) {
  if(node == NULL) return NULL;
  else if(node->value->ptr > (size_t)ptr) return _get_cont_rec(node->left, ptr);
  else if(node->value->ptr+node->value->size > (size_t)ptr) return node->value;
  else return _get_cont_rec(node->right, ptr);
}


struct _block* __get_cont(void* ptr) {
  return _get_cont_rec(__root, ptr);
}


void __clean_rec(struct _node * ptr) {
  if(ptr == NULL) return;
  __clean_block(ptr->value);
  __clean_rec(ptr->left);
  __clean_rec(ptr->right);
  free(ptr);
  ptr = NULL;
}

void __clean_struct() {
  __clean_rec(__root);
}


void __debug_rec(struct _node * ptr) {
  if(ptr == NULL) return;
  __debug_rec(ptr->left);
  printf("\t\t\t");
  __print_block(ptr->value);
  __debug_rec(ptr->right);
}

void __debug_struct() {
  printf("\t\t\t------------DEBUG\n");
  __debug_rec(__root);
  printf("\t\t\t-----------------\n");
}

