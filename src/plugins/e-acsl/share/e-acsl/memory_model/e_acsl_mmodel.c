
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "e_acsl_bittree.h"
#include "e_acsl_mmodel_api.h"

/*#define KEEP_FREED_MEMORY*/

int __cpt_store = 0, __cpt_malloc = 0;

void _clean_init (struct _block * ptr) {
  if(ptr->init_ptr != NULL) {
    free(ptr->init_ptr);
    ptr->init_ptr = NULL;
  }
  ptr->init_cpt = 0;
}


void _clean_block (struct _block * ptr) {
  if(ptr == NULL)
    return;
  _clean_init(ptr);
  free(ptr);
  ptr = NULL;
}


void _print_block (struct _block * ptr) {
  if (ptr != NULL) {
    printf("%p %zu %s ; [init] : %li ",
	   ptr->ptr,
	   ptr->size,
	   ptr->valid? "valid":"invalid",
	   ptr->init_cpt);
    if(ptr->init_ptr != NULL) {
      unsigned i;
      for(i = 0; i < ptr->size; i++)
	printf("%i", ptr->init_ptr[i]);
    }
    printf("\n");
  }
}


void* _store_block(void* tmp, size_t size) {
#ifdef KEEP_FREED_MEMORY 
  struct _block *cont, *next, *ptr;
#else
  struct _block *ptr;
#endif
  __cpt_store++;
#ifdef KEEP_FREED_MEMORY
  cont = _get_cont(tmp);
  if(cont != NULL) {
    /* si cont commence avant => chevauchement à gauche */
    if(cont->ptr < tmp) {
      /* cont se termine en plein milieu */
      if(tmp + size >= cont->ptr + cont->size)
	cont->size = tmp - cont->ptr;
      /* cont se termine après => chevauchement à droite */
      else {
	struct _block * after;
	after = malloc(sizeof(struct _block));
	if(after == NULL)
	  return NULL;
	after->ptr = tmp + size;
	after->size = cont->ptr + cont->size
	  - after->ptr;
	after->valid = 0; /* false */
	cont->size = tmp - cont->ptr;
	_add_element(after);
      }
    }
  }

  for(; (next = _get_next(tmp)) != NULL ;) {
    if(next->ptr >= tmp + size)
      break;
    /* next se termine en plein milieu => on supprime */
    if(tmp + size >= next->ptr + next->size) {
      _remove_element(next);
      free(next);
      next = NULL;
    }
    /* next se termine après => chevauchement à droite */
    else {
      struct _block * after;
      after = malloc(sizeof(struct _block));
      if(after == NULL)
	return NULL;
      after->ptr = tmp + size;
      after->size = next->ptr + next->size - after->ptr;
      after->valid = 0; /* false */
      _remove_element(next);
      free(next);
      next = NULL;
      _add_element(after);
    }
  }
#endif
  ptr = malloc(sizeof(struct _block));
  if(ptr == NULL)
    return NULL;
  ptr->ptr = tmp;
  ptr->size = size;
  ptr->valid = 1; /* true */
  ptr->init_ptr = NULL;
  ptr->init_cpt = 0;
  _add_element(ptr);
  return ptr->ptr;
}


void _delete_block(void* ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return;
  tmp = _get_exact(ptr);
  if(tmp == NULL)
    return;
  _clean_init(tmp);
  _remove_element(tmp);
  free(tmp);
  tmp = NULL;
}


void* _malloc(size_t size) {
  void * tmp;
  if(size <= 0)
    return NULL;
  tmp = malloc(size);
  if(tmp == NULL)
    return NULL;
  __cpt_malloc++;
  return _store_block(tmp, size);
}


void _free(void* ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return;
  tmp = _get_exact(ptr);
  if(tmp == NULL)
    return;
  free(tmp->ptr);
  _clean_init(tmp);
#ifdef KEEP_FREED_MEMORY
  tmp->valid = 0; /* false */
#else
  _remove_element(tmp);
  free(tmp);
  tmp = NULL;
#endif
}


void* _realloc(void* ptr, size_t size) {
#ifdef KEEP_FREED_MEMORY
  struct _block *tmp, *next;
#else
  struct _block *tmp;
#endif
  
  if(ptr == NULL)
    return _malloc(size);
  if(size <= 0) {
    _free(ptr);
    ptr = NULL;
    return NULL;
  }
  tmp = _get_exact(ptr);
  if(tmp == NULL)
    return NULL;
  tmp->ptr = realloc(tmp->ptr, size);
  tmp->valid = 1; /* true */

  /* uninitialized, do nothing */
  if(tmp->init_cpt == 0) ;
  /* already initialized block */
  else if (tmp->init_cpt == tmp->size) {
    /* realloc smaller block */
    if(size <= tmp->size)
      /* adjust new size, allocation not necessary */
      tmp->init_cpt = size;
    /* realloc bigger larger block */
    else {
      tmp->init_ptr = malloc(size*sizeof(char));
      memset(tmp->init_ptr, 1, tmp->size);
      memset(tmp->init_ptr + tmp->size, 0, size - tmp->size);
    }
  }
  /* contains initialized and uninitialized parts */
  else
    tmp->init_ptr = realloc(tmp->init_ptr, size*sizeof(char));

  tmp->size = size;
#ifdef KEEP_FREED_MEMORY
  for(; (next = _get_next(tmp->ptr)) != NULL ;) {
    if(next->ptr >= tmp->ptr + size)
      break;
    /* next se termine en plein milieu => on supprime */
    if(tmp->ptr + size >= next->ptr + next->size) {
      _remove_element(next);
      free(next);
      next = NULL;
    }
    /* next se termine après => chevauchement à droite */
    else {
      struct _block * after;
      after = malloc(sizeof(struct _block));
      if(after == NULL)
	return NULL;
      after->ptr = tmp->ptr + size;
      after->size = next->ptr + next->size - after->ptr;
      after->valid = 0; /* false */
      _remove_element(next);
      free(next);
      next = NULL;
      _add_element(after);
    }
  }
#endif
  return tmp->ptr;
}


void* _calloc(size_t nbr_block, size_t size_block) {
  void * tmp;
  if(nbr_block * size_block <= 0)
    return NULL;
  tmp = calloc(nbr_block, size_block);
  if(tmp == NULL)
    return NULL;
  return _store_block(tmp, nbr_block * size_block);
}

void _initialize (void * ptr, size_t size) {
  struct _block * tmp;
  unsigned i;
  if(ptr == NULL || size <= 0)
    return;
  tmp = _get_cont(ptr);
  if(tmp == NULL)
    return;

  /* already fully initialized, do nothing */
  if(tmp->init_cpt == tmp->size)
    return;

  /* fully uninitialized */
  if(tmp->init_cpt == 0) {
    tmp->init_ptr = malloc(tmp->size * sizeof(char));
    memset(tmp->init_ptr, 0, tmp->size);
  }

  for(i = 0; i < size; i++) {
    if(!tmp->init_ptr[i + (char*)ptr /* JS: suspicious */ - tmp->ptr])
      tmp->init_cpt++;
    tmp->init_ptr[i + (char*)ptr /* JS: suspicious */ - tmp->ptr] = 1;
  }

  /* now fully initialized */
  if(tmp->init_cpt == tmp->size) {
    free(tmp->init_ptr);
    tmp->init_ptr = NULL;
  }
}

void _full_init (void * ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return;
  tmp = _get_exact(ptr);
  if(tmp == NULL)
    return;

  if (tmp->init_ptr != NULL) {
    free(tmp->init_ptr);
    tmp->init_ptr = NULL;
  }

  tmp->init_cpt = tmp->size;
}

int _initialized (void * ptr, size_t size) {
  struct _block * tmp;
  unsigned i;
  if(ptr == NULL || size < 0)
    return 0; /* false */
  tmp = _get_cont(ptr);
  if(tmp == NULL)
    return 0; /* false */

  /* fully uninitialized */
  if(tmp->init_cpt == 0)
    return 0; /* false */
  /* fully initialized */
  if(tmp->init_cpt == tmp->size)
    return 1; /* true */

  for(i = 0; i < size; i++)
    /* if one byte is uninitialized */
    if(!tmp->init_ptr[i + (char*)ptr /* JS: suspicious */ - tmp->ptr])
      return 0; /* false */
  return 1; /* true */
}


/* Do not verify whether PTR is valid! */
size_t _block_length(void* ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return 0;
  tmp = _get_cont(ptr);
  if(tmp == NULL)
    return 0;
  return tmp->ptr + tmp->size - (char*)ptr /* JS: suspicious */;
}


int _valid(void* ptr, size_t size) {
  struct _block * tmp;
  if(ptr == NULL || size < 0)
    return 0; /* false */
  tmp = _get_cont(ptr);
  if(tmp == NULL)
    return 0; /* false */
  return
    (tmp->ptr + tmp->size - (char*)ptr /* JS: suspicious */ >= size) 
    && tmp->valid;
}


/* Do not verify whether PTR is valid ! */
void* _base_addr(void* ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return NULL;
  tmp = _get_cont(ptr);
  if(tmp == NULL)
    return NULL;
  return tmp->ptr;
}


/* Do not verify whether PTR is valid ! */
int _offset(void* ptr, size_t size) {
	struct _block * tmp;
	if(ptr == NULL || size < 0)
		return -1; /* error */
	tmp = _get_cont(ptr);
	if(tmp == NULL)
		return -1; /* error */
	return ((char*)ptr /* JS: suspicious */ - tmp->ptr) / size;
}


void __clean() {
  __clean_struct();
  /*  printf("cpt store: %i\n", __cpt_store);
      printf("cpt malloc: %i\n", __cpt_malloc);*/
}


void __debug() {
  __debug_struct();
}
