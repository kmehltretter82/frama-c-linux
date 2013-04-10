
#ifndef E_ACSL_MMODEL
#define E_ACSL_MMODEL

#include "stdlib.h"
#include "stdbool.h"

/* allocate size bytes and store the returned block
 * for further information, see malloc */
void * __malloc(size_t size)
  __attribute__((FC_BUILTIN)) ;

/* free the block starting at ptr,
 * for further information, see free */
void __free(void * ptr)
  __attribute__((FC_BUILTIN));

/* resize the block starting at ptr to fit its new size,
 * for further information, see realloc */
void * __realloc(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/* allocate memory for an array of nbr_block elements of size_block size,
 * this memory is set to zero, the returned block is stored,
 * for further information, see calloc */
void * __calloc(size_t nbr_elt, size_t size_elt)
  __attribute__((FC_BUILTIN));

/* From outside the library, the following functions have no side effect */

/* store the block of size bytes starting at ptr */
/*@ assigns \nothing; */
void * __store_block(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/* remove the block starting at ptr */
/*@ assigns \nothing; */
void __delete_block(void * ptr)
  __attribute__((FC_BUILTIN));

/* mark the size bytes of ptr as initialized */
/*@ assigns \nothing; */
void __initialize(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/* mark all bytes of ptr as initialized */
/*@ assigns \nothing; */
void __full_init(void * ptr)
  __attribute__((FC_BUILTIN));

/* marks a block as litteral string */
/*@ assigns \nothing; */
void __literal_string(void * ptr)
  __attribute__((FC_BUILTIN));

/* ****************** */
/* E-ACSL annotations */
/* ****************** */

/* return whether the first size bytes of ptr are readable/writable */
/*@ assigns \nothing; */
int __valid(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/* return whether the first size bytes of ptr are readable */
/*@ assigns \nothing; */
int __valid_read(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/* return the base address of the block containing ptr */
/*@ assigns \nothing; */
void * __base_addr(void * ptr)
  __attribute__((FC_BUILTIN));

/* return the length (in bytes) of the block containing ptr */
/*@ assigns \nothing; */
size_t __block_length(void * ptr)
  __attribute__((FC_BUILTIN));

/* return the offset of ptr within its block */
/*@ assigns \nothing; */
int __offset(void * ptr)
  __attribute__((FC_BUILTIN));

/* return whether the size bytes of ptr are initialized */
/*@ ensures \result == 0 || \result == 1;
  @ ensures \result == 1 ==> \initialized(((char *)ptr)+(0..size-1));
  @ assigns \nothing; */
int __initialized(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

void __out_of_bound(void * ptr, _Bool flag)
  __attribute__((FC_BUILTIN));

/* print the content of the abstract structure */
void __debug(void)
  __attribute__((FC_BUILTIN));

/* erase the content of the abstract structure
 * have to be called at the end of the `main` */
void __clean(void)
  __attribute__((FC_BUILTIN));

/* return the number of bytes dynamically allocated */
size_t __get_memory_size(void)
  __attribute__((FC_BUILTIN));

/* for predicates */
extern size_t __memory_size;

/*@ predicate diffSize{L1,L2}(integer i) =
  \at(__memory_size, L1) - \at(__memory_size, L2) == i;
*/

#endif
