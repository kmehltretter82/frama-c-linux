/*
 * cabin.h
 *
 *  Created on: 8 février 2011
 *      Author: rapin  CEA LIST
 */

#ifndef CABIN_H_
#define CABIN_H_

#include <stdlib.h>
#include "transitions.h"
#include "elevator.h"
#include "door.h"



enum cabine_direction_state
{
	cabin_waiting = 0,
	cabin_going_up = 1,
	cabin_going_down = -1
};

enum cabine_move_state
{
	cabin_stoped,
	cabin_moving_up,
	cabin_moving_down
};



struct cabin_call_
{
	int floor;
	char called;
	unsigned date;

};

struct cabin_
{
#ifdef ELEVATOR_RENDERING
	int previous_y;
#endif

	unsigned id;

	double speed;

	double cumul_speed;

	char opening_button;

	char accepting_ext_calls;

	int target_floor;

	int last_stop;

	cabin_call internal_calls[NB_FLOORS]; // tableau des appels internes à la cabine

	struct door_ * door; // porte de la cabine

	enum cabine_direction_state dir_state; // état logique de direction

	enum cabine_move_state mov_state; // état physique de mouvement

	int micro_position; // il y  GRANULOSITE steps entre deux étages

	div_t macro_position; // == div( micro_position, GRANULOSITE), donc

	trans_list * ts_4_mov_state; // liste de transitions depuis un état de direction

	trans_list * ts_4_dir_state;// liste de transitions depuis un état de mouvement

};

trans_list * cabin_tl_from_waiting;
trans_list * cabin_tl_from_going_up;
trans_list * cabin_tl_from_going_down;
trans_list * cabin_tl_from_stoped;
trans_list * cabin_tl_from_mov;

cabin * cabins[NB_CABINS];

void cabin_trans_init(cabin * cb);
void reset_internal_call(int, cabin_call *);
void cabin_execution_step(cabin *);
void cabin_ts_init(void);


#ifdef ELEVATOR_RENDERING
void cabin_rendering(cabin * cb);
#endif /* ELEVATOR_RENDERING */


#endif /* CABIN_H_ */
