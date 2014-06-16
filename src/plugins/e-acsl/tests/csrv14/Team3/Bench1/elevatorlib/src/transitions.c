/*
 * transition.c
 *
 *  Created on: 8 févr. 2011
 *      Author: rapin  CEA LIST
 */


#include "transitions.h"

trans_list * new_trans_list()
{
	trans_list * res = RESERVER(1,trans_list);

	res->first = res->last = NULL;

	return res;
}


void trans_list_push_back(trans_list * tl, void * func)
{

	trans_elem * new_te = RESERVER(1,trans_elem);

	new_te->trans_func = func;

	new_te->next = NULL;

	if (tl->last)
		tl->last->next = new_te;
	else
		tl->first = new_te;

	tl->last = new_te;

}
