/*
 * transitions.h
 *
 *  Created on: 8 févr. 2011
 *      Author: rapin CEA LIST
 */

#ifndef TRANSITIONS_H_
#define TRANSITIONS_H_

#include <stdlib.h>
#include "macros.h"

#define GUARD(x) if (!(x)) return 0;

typedef struct transition_elem_
{
	int (* trans_func)(void *);

	struct transition_elem_ * next;

} trans_elem;

typedef struct
{
	trans_elem * first;
	trans_elem * last;

} trans_list;

trans_list * new_trans_list();
void trans_list_push_back(trans_list*, void *);




#endif /* TRANSITIONS_H_ */
