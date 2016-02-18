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

#ifndef E_ACSL_SPLAYTREE
#define E_ACSL_SPLAYTREE

#include "e_acsl_malloc.h"
#include "e_acsl_syscall.h"
#include "e_acsl_printf.h"
#include "e_acsl_assert.h"
#include "e_acsl_adt_api.h"

static struct _node {
  struct _block * value;
  struct _node * left, * right, * parent;
};

static struct _node * __root = NULL;

static void left_rotate(struct _node * x) {
  struct _node* y = x->right;
  x->right = y->left;
  if( y->left ) y->left->parent = x;
  y->parent = x->parent;
  if( !x->parent ) __root = y;
  else if( x == x->parent->left ) x->parent->left = y;
  else x->parent->right = y;
  y->left = x;
  x->parent = y;
}

static void right_rotate(struct _node *x ) {
  struct _node *y = x->left;
  x->left = y->right;
  if( y->right ) y->right->parent = x;
  y->parent = x->parent;
  if( !x->parent ) __root = y;
  else if( x == x->parent->left ) x->parent->left = y;
  else x->parent->right = y;
  y->right = x;
  x->parent = y;
}

static void splay(struct _node *x ) {
  while( x->parent ) {
    if( !x->parent->parent ) {
      if( x->parent->left == x ) right_rotate( x->parent );
      else left_rotate( x->parent );
    }
    else if( x->parent->left == x && x->parent->parent->left == x->parent ) {
      right_rotate( x->parent->parent );
      right_rotate( x->parent );
    }
    else if( x->parent->right == x && x->parent->parent->right == x->parent ) {
      left_rotate( x->parent->parent );
      left_rotate( x->parent );
    }
    else if( x->parent->left == x && x->parent->parent->right == x->parent ) {
      right_rotate( x->parent );
      left_rotate( x->parent );
    }
    else {
      left_rotate( x->parent );
      right_rotate( x->parent );
    }
  }
}

static struct _node* subtree_minimum(struct _node *u ) {
  while( u->left ) u = u->left;
  return u;
}

static struct _node* subtree_maximum(struct _node *u ) {
  while( u->right ) u = u->right;
  return u;
}

static void replace(struct _node *u, struct _node *v ) {
  if( !u->parent ) __root = v;
  else if( u == u->parent->left ) u->parent->left = v;
  else u->parent->right = v;
  if( v ) v->parent = u->parent;
}

static void __remove_element(struct _block* ptr) {
  struct _node * z = __root;
  while(z != NULL) {
    if(z->value->ptr > ptr->ptr) z = z->left;
    else if(z->value->ptr < ptr->ptr) z = z->right;
    else break;
  }
  if( !z ) return;
  splay( z );

  if( !z->left ) replace( z, z->right );
  else if( !z->right ) replace( z, z->left );
  else {
    struct _node *y = subtree_minimum( z->right );
    if( y->parent != z ) {
      replace( y, y->right );
      y->right = z->right;
      y->right->parent = y;
    }
    replace( z, y );
    y->left = z->left;
    y->left->parent = y;
  }
}

static void __add_element(struct _block* ptr) {
  struct _node *z = __root, *p = NULL;
  while( z ) {
    p = z;
    if(z->value->ptr > ptr->ptr) z = z->left;
    else if(z->value->ptr < ptr->ptr) z = z->right;
    else return;
  }
  z = native_malloc(sizeof(struct _node));
  z->left = z->right = NULL;
  z->value = ptr;
  z->parent = p;
  if( !p ) __root = z;
  else if(p->value->ptr < z->value->ptr) p->right = z;
  else p->left = z;
  splay( z );
}

static struct _block* __get_exact(void* ptr) {
  struct _node * tmp = __root;
  while(tmp != NULL) {
    if(tmp->value->ptr > (size_t)ptr) tmp = tmp->left;
    else if(tmp->value->ptr < (size_t)ptr) tmp = tmp->right;
    else return tmp->value;
  }
  return NULL;
}

static struct _block* _get_cont_rec(struct _node * node, void* ptr) {
  if(node == NULL) return NULL;
  else if(node->value->ptr > (size_t)ptr) return _get_cont_rec(node->left, ptr);
  else if(node->value->size == 0 && node->value->ptr == (size_t)ptr)
    return node->value;
  else if(node->value->ptr+node->value->size > (size_t)ptr) return node->value;
  else return _get_cont_rec(node->right, ptr);
}

static struct _block* __get_cont(void* ptr) {
  return _get_cont_rec(__root, ptr);
}

static void __clean_rec(struct _node * ptr) {
  if(ptr == NULL) return;
  __clean_block(ptr->value);
  __clean_rec(ptr->left);
  __clean_rec(ptr->right);
  native_free(ptr);
  ptr = NULL;
}

static void __clean_struct() {
  __clean_rec(__root);
}

/*********************/
/* DEBUG             */
/*********************/
#ifdef E_ACSL_DEBUG
static void debug_rec(struct _node * ptr) {
  if(ptr == NULL) return;
  debug_rec(ptr->left);
  DLOG("\t\t\t");
  __e_acsl_print_block(ptr->value);
  debug_rec(ptr->right);
}

static void debug_struct() {
  DLOG("\t\t\t------------DEBUG\n");
  debug_rec(__root);
  DLOG("\t\t\t-----------------\n");
}

#endif
#endif
