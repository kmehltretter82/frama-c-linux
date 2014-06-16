/*
 * ext_call.c
 *
 *  Created on: 2 mars 2011
 *      Author: rapin  CEA LIST
 */

#include <limits.h>
#include "ext_call.h"
#include "cabin.h"


int pop_ext_call()
{
	int res;
	ext_call * tmp =  ext_calls_buffer->first;

	if (tmp)
	{
		res = tmp->floor_number;
		ext_calls_buffer->first = tmp->next;

		if (ext_calls_buffer->first == NULL)
			ext_calls_buffer->last = NULL;

		free(tmp);

		return res;

	}

	return NOT_A_FLOOR;

}

void push_ext_call(int floor)
{

	ext_call * n = RESERVER(1,ext_call);

	n->floor_number = floor;
	n->next = NULL;

	if (ext_calls_buffer->last)
	{
		ext_calls_buffer->last->next = n;
	}
	else
	{
		ext_calls_buffer->last = ext_calls_buffer->first = n;
	}

}

// on dépile un appel externe
// et on lui assigne la cabine la plus proche
void ext_call_cabin_assignation(unsigned date)
{
	int floor;

	cabin * cb;
	unsigned ecart;
	int ecart_tmp;
	int j;
	int one_free = 0;

	for(j = 0 ; j < NB_CABINS ; j++)
	{
		if (cabins[j]->accepting_ext_calls)
		{
			one_free = 1;
			break;
		}
	}

	if (! one_free)
		return;

	floor = pop_ext_call();

	// buffer vide
	if (floor == NOT_A_FLOOR)
		return;

	// floor est déjà attribué à une cabine
	if(ext_calls_votes[floor] != NOT_A_FLOOR)
		return;




	ecart = UINT_MAX;

	for(j = 0 ; j < NB_CABINS ; j++)
	{
		cb = cabins[j];

		// REQ_8
		if (cb->accepting_ext_calls)
		{
			ecart_tmp = (floor * GRANULOSITE) - cb->micro_position;

			if (ecart_tmp * cb->dir_state < 0)
				ecart_tmp = ecart_tmp * 2;

			if (ecart_tmp < 0)
				ecart_tmp = - ecart_tmp;

			if (ecart_tmp < ecart)
			{
				fprintf(TRACE_FILE,"ext_call %d affected to cabin %d\n",floor,cb->id);
				ext_calls_votes[floor] = cb->id;
				ext_calls_dates[floor] = date;
				ecart = ecart_tmp;
			}
		}
	}
}


void ext_calls_init()
{
	int i;

	for(i = 0 ; i < NB_FLOORS ; i++)
	{
		ext_calls_votes[i] = NOT_A_FLOOR;
		ext_calls_dates[i] = UINT_MAX;
	}

}
