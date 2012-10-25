#ifndef E_ACSL_MMODEL_API
#define E_ACSL_MMODEL_API

#include "stdlib.h"

/* Memory block allocated and may be deallocated */
struct _block {
	char* ptr;	/* begin address */
	size_t size;	/* size in bytes */
	int valid;	/* whether the block has not been deallocated yet */
/* Keep trace of initialized sub-blocks within a memory block */
	unsigned char * init_ptr; /* dynamic array of booleans */
	unsigned long init_cpt;
};

void _print_block (struct _block * ptr);
void _clean_init (struct _block * ptr);
void _clean_block (struct _block * ptr);

/* functions to be implemented */

void            _remove_element ( struct _block * );
void            _add_element    ( struct _block * );
struct _block * _get_exact      ( void * );
struct _block * _get_next       ( void * );
struct _block * _get_cont       ( void * );
void            __clean_struct  ( );
void            __debug_struct  ( );

#endif
