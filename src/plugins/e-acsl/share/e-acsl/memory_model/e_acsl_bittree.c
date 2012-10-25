
#include <assert.h>
#include <errno.h>
#include <unistd.h>
#include "stdio.h"
#include "e_acsl_mmodel_api.h"
#include "e_acsl_bittree.h"
#include "e_acsl_mmodel.h"

#define WORDBITS 64

struct bittree {
  int is_leaf;
  char* addr;
  unsigned long mask;
  struct bittree * left;
  struct bittree * right;
  struct bittree * father;
  struct _block * leaf;
} * __root = NULL;

unsigned long Tmasks[] = {
0x0,
0x8000000000000000,
0xc000000000000000,
0xe000000000000000,
0xf000000000000000,
0xf800000000000000,
0xfc00000000000000,
0xfe00000000000000,
0xff00000000000000,
0xff80000000000000,
0xffc0000000000000,
0xffe0000000000000,
0xfff0000000000000,
0xfff8000000000000,
0xfffc000000000000,
0xfffe000000000000,
0xffff000000000000,
0xffff800000000000,
0xffffc00000000000,
0xffffe00000000000,
0xfffff00000000000,
0xfffff80000000000,
0xfffffc0000000000,
0xfffffe0000000000,
0xffffff0000000000,
0xffffff8000000000,
0xffffffc000000000,
0xffffffe000000000,
0xfffffff000000000,
0xfffffff800000000,
0xfffffffc00000000,
0xfffffffe00000000,
0xffffffff00000000,
0xffffffff80000000,
0xffffffffc0000000,
0xffffffffe0000000,
0xfffffffff0000000,
0xfffffffff8000000,
0xfffffffffc000000,
0xfffffffffe000000,
0xffffffffff000000,
0xffffffffff800000,
0xffffffffffc00000,
0xffffffffffe00000,
0xfffffffffff00000,
0xfffffffffff80000,
0xfffffffffffc0000,
0xfffffffffffe0000,
0xffffffffffff0000,
0xffffffffffff8000,
0xffffffffffffc000,
0xffffffffffffe000,
0xfffffffffffff000,
0xfffffffffffff800,
0xfffffffffffffc00,
0xfffffffffffffe00,
0xffffffffffffff00,
0xffffffffffffff80,
0xffffffffffffffc0,
0xffffffffffffffe0,
0xfffffffffffffff0,
0xfffffffffffffff8,
0xfffffffffffffffc,
0xfffffffffffffffe,
0xffffffffffffffff};

int __cpt_mask = 0;

int Teq[] = {0,-1,3,-3,6,-5,7,-7,12,-9,11,-11,14,-13,15,-15,24,-17,19,-19,22,-21,23,-23,28,-25,27,-27,30,-29,31,-31,48,-33,35,-35,38,-37,39,-39,44,-41,43,-43,46,-45,47,-47,56,-49,51,-51,54,-53,55,-55,60,-57,59,-59,62,-61,63,64,-64};

int Tneq[] = {0,0,1,-2,2,-4,5,-6,4,-8,9,-10,10,-12,13,-14,8,-16,17,-18,18,-20,21,-22,20,-24,25,-26,26,-28,29,-30,16,-32,33,-34,34,-36,37,-38,36,-40,41,-42,42,-44,45,-46,40,-48,49,-50,50,-52,53,-54,52,-56,57,-58,58,-60,61,-62,-63};

/* common bits of two addresses */

unsigned long mask(void * a, void * b) {
  unsigned long nxor = ~((unsigned long)a ^ (unsigned long)b);
  int i = WORDBITS/2;
  __cpt_mask++;

  while(i > 0)
    i = (nxor >= Tmasks[i]) ? Teq[i] : Tneq[i];
  return Tmasks[-i];
}

/* binary conjuction of a bittree and a new node */
void* and(struct bittree * a, struct _block * b) {
  return (void*) ((unsigned long)a->addr & (unsigned long)b->ptr);
}

/* does an address matches the mask of a bittree ? */
int matches_mask(struct bittree * a, void * b) {
  return ((unsigned long)a->addr & a->mask) == ((unsigned long)b & a->mask);
}

/********************/

void _remove_element (struct _block * ptr) {
  struct bittree * curr = __root;
  if(__root == NULL || ptr == NULL)
    return;

  if(__root->is_leaf) {
    if(__root->addr == ptr->ptr) {
      free(__root);
      __root = NULL;
    }
    return;
  }

  while(1) {
    /* does not match the mask */
    if(!matches_mask(curr, ptr->ptr))
      break;

    /* element to delete */
    if(curr->is_leaf) {
      struct bittree * to_up, * cf;
      assert(curr->father != NULL);

      to_up = (curr == curr->father->left)?
	curr->father->right : curr->father->left;
      cf = curr->father;
      assert(to_up != NULL);

      cf->is_leaf = to_up->is_leaf;
      cf->addr = to_up->addr;
      cf->mask = to_up->mask;
      cf->left = to_up->left;
      cf->right = to_up->right;
      cf->leaf = to_up->leaf;

      if(!to_up->is_leaf) {
	to_up->left->father = cf;
	to_up->right->father = cf;
      }

      free(to_up);
      free(curr);

      break;
    }

    /* visit child with most bits in common */
    assert(curr->left != NULL && curr->right != NULL);
    curr = (mask(curr->left->addr, ptr->ptr)
	    > mask(curr->right->addr, ptr->ptr))?
      curr->left : curr->right;
  }
}

/************************/

void _add_element (struct _block * ptr) {
  struct bittree * new_leaf;
  if(ptr == NULL)
    return;

  new_leaf = malloc(sizeof(struct bittree));
  new_leaf->is_leaf = 1;
  new_leaf->addr = ptr->ptr;
  new_leaf->mask = ~0;
  new_leaf->left = NULL;
  new_leaf->right = NULL;
  new_leaf->father = NULL;
  new_leaf->leaf = ptr;

  if(__root == NULL)
    __root = new_leaf;

  else {
    struct bittree * curr = __root; /* __root != NULL */

    while(1) {
      /* matches the mask */
      if(matches_mask(curr, ptr->ptr)) {
	/* already stored */
	if(curr->is_leaf) {
	  free(new_leaf);
	  assert(ptr->ptr == curr->addr);
	  break;
	}
	assert(curr->left != NULL
	       && curr->right != NULL);
	/* visit child with most bits in common */
	curr = mask(curr->left->addr, ptr->ptr)
	  > mask(curr->right->addr, ptr->ptr)
	  ? curr->left
	  : curr->right;
      }

      /* does not match the mask : creating a new node */
      else {
	struct bittree * new_node;
	new_node = malloc(sizeof(struct bittree));
	new_node->is_leaf = curr->is_leaf;
	new_node->addr = curr->addr;
	new_node->mask = curr->mask;
	new_node->left = curr->left;
	new_node->right = curr->right;
	new_node->father = curr;
	new_leaf->father = curr;
	new_node->leaf = curr->leaf;

	if(!new_node->is_leaf) {
	  new_node->left->father = new_node;
	  new_node->right->father = new_node;
	}

	curr->is_leaf = 0;
	curr->addr = and(new_node, ptr);
	curr->mask = mask(new_node->addr, ptr->ptr);
	if(new_node->addr < ptr->ptr) {
	  curr->left = new_node;
	  curr->right = new_leaf;
	} else {
	  curr->left = new_leaf;
	  curr->right = new_node;
	}
	curr->leaf = NULL;

	break;
      }
    }
  }
}

/**********************/

struct _block * _get_exact (void * ptr) {
  struct bittree * tmp = __root;
  if(__root == NULL || ptr == NULL)
    return NULL;

  while(1) {
    /* does not match the mask */
    if(!matches_mask(tmp, ptr))
      break;
    /* the leaf we are looking for */
    if(tmp->is_leaf)
      return tmp->leaf;
    /* visit child with most bits in common */
    assert(tmp->left != NULL && tmp->right != NULL);

    tmp = (mask(tmp->left->addr, ptr)
	   > mask(tmp->right->addr, ptr)) ?
      tmp->left :
      tmp->right;
  }

  return NULL;
}

/************************/

struct _block * _get_next (void * ptr) {
  struct bittree * tmp = __root;
  if(__root == NULL || ptr == NULL)
    return NULL;
  if(__root->is_leaf)
    return NULL;

  while(1) {
    /* does not match the mask */
    if(!matches_mask(tmp, ptr))
      break;
    if(tmp->is_leaf)
      break;
    /* visit child with most bits in common */
    assert(tmp->left != NULL && tmp->right != NULL);

    tmp = (mask(tmp->left->addr, ptr)
	   > mask(tmp->right->addr, ptr)) ?
      tmp->left :
      tmp->right;
  }

  if(ptr < (void*)tmp->addr)
    return NULL;
  /* we move up, as long as we are on right branches */
  while(tmp->father != NULL && tmp == tmp->father->right)
    tmp = tmp->father;
  /* tmp is at bottom right => no next leaf */
  if(tmp == __root)
    return NULL;
  /* tmp has a father and is a left child */
  tmp = tmp->father->right;
  /* we move down, following left branches */
  while(!tmp->is_leaf)
    tmp = tmp->left;
  assert(ptr < (void*)tmp->addr);
  return tmp->leaf;
}

/**************************/

struct _block * _get_cont (void * ptr) {
  struct bittree * tmp = __root;
  if(__root == NULL || ptr == NULL)
    return NULL;

  while(1) {
    if(tmp->is_leaf) {
      if(ptr < (void*)tmp->addr)
	return NULL;
      else 
	if(ptr < (void*)(tmp->addr + tmp->leaf->size))
	return tmp->leaf;
      return NULL;
    }
    assert(tmp->left != NULL && tmp->right != NULL);
    if(((unsigned long)tmp->right->addr & tmp->right->mask)
       <= ((unsigned long)ptr & tmp->right->mask))
      tmp = tmp->right;
    else if(((unsigned long)tmp->left->addr & tmp->left->mask)
	    <= ((unsigned long)ptr & tmp->left->mask))
      tmp = tmp->left;
    else
      return NULL;
  }
}

/**************************/

void __clean_rec (struct bittree * ptr) {
  if(ptr == NULL)
    return;
  if(ptr->is_leaf) {
    _clean_block(ptr->leaf);
    ptr->leaf = NULL;
  } else {
    __clean_rec(ptr->left);
    ptr->left = NULL;
    __clean_rec(ptr->right);
    ptr->right = NULL;
  }
  free(ptr);
  ptr = NULL;
}

void __clean_struct () {
  __clean_rec(__root);
  /*  printf("cpt mask: %i\n", __cpt_mask);*/
}

/*********************/

void __debug_rec (struct bittree * ptr) {
  if(ptr == NULL)
    return;
  if(ptr->is_leaf) {
    printf("\t\t\t");
    _print_block(ptr->leaf);
  } else {
    __debug_rec(ptr->left);
    __debug_rec(ptr->right);
  }
}

void __debug_struct () {
  printf("\t\t\t------------DEBUG\n");
  __debug_rec(__root);
  printf("\t\t\t-----------------\n");
}
