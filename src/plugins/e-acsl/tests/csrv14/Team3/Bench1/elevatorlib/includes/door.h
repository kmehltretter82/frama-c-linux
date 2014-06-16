/*
 * door.h
 *
 *  Created on: 7 mars 2011
 *      Author: rapin  CEA LIST
 */

#ifndef DOOR_H_
#define DOOR_H_

#include "transitions.h"
#include "elevator.h"
#include "cabin.h"

#define LOCK_POS 5
#define MOVE_DELAY 3

enum cabin_door_status
{
	opening,
	closing,
	totally_open,
	totally_closed,
	mov_enabled
};

struct door_
{

	enum cabin_door_status ds;

	unsigned ttly_closed_since;

	unsigned ttly_open_since;

	cabin * cb;

	unsigned pos; // when 0: ttly open, LOCK_POS : ttly closed

	trans_list * tl;

};

trans_list * door_tl_from_opening;
trans_list * door_tl_from_closing;
trans_list * door_tl_from_totally_open;
trans_list * door_tl_from_totally_closed;
trans_list * door_tl_from_start_enabled;

void door_ts_init();
void door_init_trans(door *);
void door_simulation(door * d);

#ifdef ELEVATOR_RENDERING
void door_rendering(cabin * cb, int x, int y);
#endif /* ELEVATOR_RENDERING */


#endif /* DOOR_H_ */
