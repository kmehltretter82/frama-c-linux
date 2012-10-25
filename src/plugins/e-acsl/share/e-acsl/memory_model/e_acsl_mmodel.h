
#ifndef E_ACSL_MMODEL
#define E_ACSL_MMODEL

#include "stdlib.h"

void * _malloc(size_t size)
  __attribute__((FC_BUILTIN)) ;

void _free(void * ptr)
  __attribute__((FC_BUILTIN));

void * _realloc(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

void * _calloc(size_t nbr_elt, size_t size_elt)
  __attribute__((FC_BUILTIN));

/* From outside the library, the following functions have no side effect */

/*@ assigns \nothing; */
void * _store_block(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*@ assigns \nothing; */
void _delete_block(void * ptr)
  __attribute__((FC_BUILTIN));

/*@ assigns \nothing; */
void _initialize(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*@ assigns \nothing; */
void _full_init(void * ptr)
  __attribute__((FC_BUILTIN));

/* ****************** */
/* E-ACSL annotations */
/* ****************** */

/*@ assigns \nothing; */
int _valid(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*@ assigns \nothing; */
void * _base_addr(void * ptr)
  __attribute__((FC_BUILTIN));

/*@ assigns \nothing; */
size_t _block_length(void * ptr)
  __attribute__((FC_BUILTIN));

/*@ assigns \nothing; */
int _offset(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

/*@ ensures \result == 0 || \result == 1;
  @ ensures \result == 1 ==> \initialized(((char *)ptr)+(0..size-1));
  @ assigns \nothing; */
int _initialized(void * ptr, size_t size)
  __attribute__((FC_BUILTIN));

void __debug(void)
  __attribute__((FC_BUILTIN));

void __clean(void)
  __attribute__((FC_BUILTIN));

#endif
