/*
 * testing.c
 *
 *  Created on: 14 mars 2011
 *      Author: rapin  CEA LIST
 */

#include "ext_call.h"
#include "cabin.h"
#include "elevator.h"

void internal_call_func(int id_cabin, int floor, unsigned step)
{

	fprintf(TRACE_FILE,"cabin(%d) : appel interne à l'étage %d\n",id_cabin,floor);
	cabins[id_cabin-1]->internal_calls[floor].called = 1;
	cabins[id_cabin-1]->internal_calls[floor].date   = step;

}

void run_until_to_func(unsigned nb_step, unsigned * i)
{
	unsigned j;

	for( j = (*i) ; j <= nb_step ; j++)
	{
		fprintf(TRACE_FILE,"\n<step %d>\n",j+1);
		elevator_execution_step(j);
	}

	(*i) = j;

}

void press_open_func(int cb_id)
{

	fprintf(TRACE_FILE,"on presse le bouton opening cabin %d\n",cb_id);
	cabins[cb_id-1]->opening_button = 1;
}

void relax_open_func(int cb_id)
{
	fprintf(TRACE_FILE,"on relache le bouton opening cabin %d\n",cb_id);
	cabins[cb_id-1]->opening_button = 0;
}

void run_func(unsigned * i)
{
	(*i) = (*i) + 1;
	fprintf(TRACE_FILE,"\n<step %d>\n",(*i)+1);
	elevator_execution_step((*i));
}
