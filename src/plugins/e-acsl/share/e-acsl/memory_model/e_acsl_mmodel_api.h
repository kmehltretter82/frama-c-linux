#ifndef E_ACSL_MMODEL_API
#define E_ACSL_MMODEL_API

#include "stdlib.h"
#include "stdbool.h"

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
void _print_block ( struct _block * ptr );
/* erase information about initialization of a block */
void _clean_init  ( struct _block * ptr );
/* erase all information about a block */
void _clean_block ( struct _block * ptr );


/* functions to be implemented */


/* remove the block from the structure */
void            _remove_element ( struct _block * );
/* add a block in the structure */
void            _add_element    ( struct _block * );
/* return the block B such as : begin addr of B == ptr
   we suppose that such a block exists, but we could return NULL if not */
struct _block * _get_exact      ( void * );
/* return the block B such as : begin addr of B > ptr
   or NULL if such a block does not exist */
struct _block * _get_next       ( void * );
/* return the block B containing ptr, such as :
   begin addr of B <= ptr < (begin addr + size) of B
   or NULL if such a block does not exist */
struct _block * _get_cont       ( void * );
/* erase the content of the structure */
void            __clean_struct  ( );
/* print the content of the structure */
void            __debug_struct  ( );

#endif
