/*
 * ext_call.h
 *
 *  Created on: 10 févr. 2011
 *      Author: rapin  CEA LIST
 */

#ifndef EXT_CALL_H_
#define EXT_CALL_H_

#include "elevator.h"

struct ext_call_
{
	int floor_number;
	struct ext_call_ * next;

};

struct ext_call_stack
{
	ext_call * first;
	ext_call * last;

};

// ext_calls_votes[i] = x si la cabine est choisie pour désservir l'appel externe i
// 0 si non appelé
int ext_calls_votes[NB_FLOORS];
unsigned ext_calls_dates[NB_FLOORS];

struct ext_call_stack * ext_calls_buffer;


int pop_ext_call();
void push_ext_call(int);

void ext_call_cabin_assignation(unsigned);
void ext_calls_init();

#endif /* EXT_CALL_H_ */
