
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
  int i = WORDBITS/2; /* dichotomic search, starting in the middle */
  
  /* if the current mask matches we use transition from Teq, else from Tneq
     we stop as soon as i is negative, meaning that we found the mask */
  while(i > 0) i = (nxor >= Tmasks[i]) ? Teq[i] : Tneq[i];

  /* a negative element i from Teq or Tneq means stop and return Tmasks[-i] */
  return Tmasks[-i];
}


/* logical AND of a bittree and a new node */
void* and(struct bittree * a, struct _block * b) {
  return (void*) ((unsigned long)a->addr & (unsigned long)b->ptr);
}

/* does an address matches the mask of a bittree ? */
int matches_mask(struct bittree * a, void * b) {
  return ((unsigned long)a->addr & a->mask) == ((unsigned long)b & a->mask);
}


/* remove the block from the structure */
void _remove_element (struct _block * ptr) {
  struct bittree * curr = __root;
  assert(__root != NULL);
  assert(ptr != NULL);

  if(__root->is_leaf) { 
    assert(__root->addr == ptr->ptr);
    free(__root);
    __root = NULL;
    return;
  }
  
  while(1) {
    /* does not match the mask */
    assert(matches_mask(curr, ptr->ptr));
    
    /* element to delete */
    if(curr->is_leaf) {
      struct bittree * brother, * cf;
      cf = curr->father;
      assert(cf != NULL);
      brother = (curr == cf->left) ? cf->right : cf->left;
      assert(brother != NULL);
      
      cf->is_leaf = brother->is_leaf;
      cf->addr = brother->addr;
      cf->mask = brother->mask;
      cf->left = brother->left;
      cf->right = brother->right;
      cf->leaf = brother->leaf;

      if(!brother->is_leaf) {
	brother->left->father = cf;
	brother->right->father = cf;
      }

      free(brother);
      free(curr);
      break;
    }
    
    assert(curr->left != NULL && curr->right != NULL);
    
    /* visit child with greatest common prefix,
       if the bit next to the mask is set to 1, go to right child,
       because its address is higher than the other */
    curr = ((curr->mask >> 1) & ( ~ curr->mask ) & (unsigned long)ptr->ptr) ?
      curr->right : curr->left;
  }
}


/* add a block in the structure */
void _add_element (struct _block * ptr) {
  struct bittree * new_leaf;
  assert(ptr != NULL);
  
  new_leaf = malloc(sizeof(struct bittree));
  assert(new_leaf != NULL);
  new_leaf->is_leaf = 1;
  new_leaf->addr = ptr->ptr;
  new_leaf->mask = ~0ul;
  new_leaf->left = new_leaf->right = new_leaf->father = NULL;
  new_leaf->leaf = ptr;
  
  if(__root == NULL) __root = new_leaf;
  else {
    struct bittree * curr = __root;
    
    while(1) {
      /* matches the mask */
      if(matches_mask(curr, ptr->ptr)) {
	/* is a leaf => already stored */
	if(curr->is_leaf)
	  return;

	assert(!curr->is_leaf);
	assert(curr->left != NULL && curr->right != NULL);

	/* visit child with greatest common prefix */
	curr =
	  ((curr->mask >> 1) & ( ~ curr->mask ) & (unsigned long)ptr->ptr) ?
	  curr->right : curr->left;
      }
      
      /* does not match the mask : creating a new node */
      else {
	struct bittree * new_node;
	new_node = malloc(sizeof(struct bittree));
	assert(new_node != NULL);
	  
	new_node->is_leaf = curr->is_leaf;
	new_node->addr = curr->addr;
	new_node->mask = curr->mask;
	new_node->left = curr->left;
	new_node->right = curr->right;
	new_node->father = curr;
	new_leaf->father = curr;
	new_node->leaf = curr->leaf;

	if(!new_node->is_leaf)
	  new_node->left->father = new_node->right->father = new_node;
	
	curr->is_leaf = 0;
	curr->mask = mask(new_node->addr, ptr->ptr);
	curr->addr = (void*)((unsigned long)and(new_node, ptr) & curr->mask);

	/* smaller at left, higher at right */
	if(new_node->addr < ptr->ptr) {
	  curr->left = new_node;
	  curr->right = new_leaf;
	}
	else {
	  curr->left = new_leaf;
	  curr->right = new_node;
	}
	curr->leaf = NULL;
	break;
      }
    }
  }
}


/* return the block B such as : begin addr of B == ptr
   we suppose that such a block exists, but we could return NULL if not */
struct _block * _get_exact (void * ptr) {
  struct bittree * tmp = __root;
  if(__root == NULL || ptr == NULL) return NULL;

  while(1) {
    /* does not match the mask */
    if(!matches_mask(tmp, ptr)) return NULL;

    /* the leaf we are looking for */
    if(tmp->is_leaf) return tmp->leaf;

    assert(tmp->left != NULL && tmp->right != NULL);
    
    /* visit child with greatest common prefix */
    tmp = ((tmp->mask >> 1) & ( ~ tmp->mask ) & (unsigned long)ptr) ?
      tmp->right : tmp->left;
  }
}


/* return the block B containing ptr, such as :
   begin addr of B <= ptr < (begin addr + size) of B
   or NULL if such a block does not exist */
struct _block * _get_cont (void * ptr) {
  struct bittree * tmp = __root;
  if(__root == NULL || ptr == NULL) return NULL;
  
  while(1) {
    if(tmp->is_leaf) {
      /* tmp cannot contain ptr because its begin addr is higher */
      if(tmp->addr > (char*)ptr) return NULL;
      /* tmp->addr <= ptr, tmp may contain ptr
	 ptr is contained if tmp is large enough (begin addr + size) */
      else if((char*)ptr < tmp->leaf->size + tmp->addr) return tmp->leaf;
      /* tmp->addr <= ptr, but tmp->addr is not large enough */
      return NULL;
    }
    
    assert(tmp->left != NULL && tmp->right != NULL);

    /* the right child has the highest address, so we test it first */
    if(((unsigned long)tmp->right->addr & tmp->right->mask)
       <= ((unsigned long)ptr & tmp->right->mask))
      tmp = tmp->right;
    else if(((unsigned long)tmp->left->addr & tmp->left->mask)
	    <= ((unsigned long)ptr & tmp->left->mask))
      tmp = tmp->left;
    else return NULL;
  }
}


/*******************/
/* CLEAN           */
/*******************/


/* recursively erase the content of the structure,
   do not call directly */
void __clean_rec (struct bittree * ptr) {
  if(ptr == NULL) return;
  else if(ptr->is_leaf) {
    _clean_block(ptr->leaf);
    ptr->leaf = NULL;
  }
  else {
    __clean_rec(ptr->left);
    __clean_rec(ptr->right);
    ptr->left = ptr->right = NULL;
  }
  free(ptr);
}

/* erase the content of the structure */
void __clean_struct () {
  __clean_rec(__root);
  __root = NULL;
}


/*********************/
/* DEBUG             */
/*********************/


/* recursively print the content of the structure
   do not call directly */
void __debug_rec (struct bittree * ptr) {
  if(ptr == NULL) return;
  else if(ptr->is_leaf) {
    printf("\t\t\t");
    _print_block(ptr->leaf);
  }
  else {
    __debug_rec(ptr->left);
    __debug_rec(ptr->right);
  }
}

/* print the content of the structure */
void __debug_struct () {
  printf("\t\t\t------------DEBUG\n");
  __debug_rec(__root);
  printf("\t\t\t-----------------\n");
}

