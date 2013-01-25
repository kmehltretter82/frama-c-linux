#ifndef E_ACSL_MMODEL_API
#define E_ACSL_MMODEL_API

#include "stdlib.h"
#include "stdbool.h"

#if E_ACSL_MACHDEP == x86_64
#define WORDBITS 64
#elif E_ACSL_MACHDEP == x86_32
#define WORDBITS 32
#elif E_ACSL_MACHDEP == ppc_32
#define WORDBITS 32
#elif E_ACSL_MACHDEP == x86_16
#define WORDBITS 16
#else
#define WORDBITS 32
#endif

/* Memory block allocated and may be deallocated */
struct _block {
  char * ptr;	/* begin address */
  size_t size;	/* size in bytes */
/* Keep trace of initialized sub-blocks within a memory block */
  unsigned char * init_ptr; /* dynamic array of booleans */
  unsigned long init_cpt;
  _Bool is_litteral_string;
};

/* print the information about a block */
void __print_block(struct _block * ptr );

/* erase information about initialization of a block */
void __clean_init(struct _block * ptr );

/* erase all information about a block */
void __clean_block(struct _block * ptr);

/* remove the block from the structure */
void  __remove_element(struct _block *);

/* add a block in the structure */
void  __add_element(struct _block *);

/* return the block B such as : begin addr of B == ptr
   we suppose that such a block exists, but we could return NULL if not */
struct _block * __get_exact(void *);

/* return the block B such as : begin addr of B > ptr
   or NULL if such a block does not exist */
struct _block * __get_next(void *);

/* return the block B containing ptr, such as :
   begin addr of B <= ptr < (begin addr + size) of B
   or NULL if such a block does not exist */
struct _block * __get_cont(void *);

/* erase the content of the structure */
void __clean_struct(void);

/* print the content of the structure */
void  __debug_struct(void);

#endif
