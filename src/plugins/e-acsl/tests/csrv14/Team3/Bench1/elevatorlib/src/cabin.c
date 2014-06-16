/*
 * cabin.c
 *
 *  Created on: 8 févr. 2011
 *      Author: rapin CEA LIST
 */


#include <limits.h>
#include "cabin.h"
#include "ext_call.h"

#ifdef ELEVATOR_RENDERING

void opening_switch_draw(int x, int y,  Uint8 R, Uint8 G, Uint8 B)
{

	int i;

	for(i = 0 ; i < OPEN_SWITCH_SIZE ; i++)
	{
		DrawPixel(x+i-1, y-i, R, G, B);
		DrawPixel(x+i-1, y+i, R, G, B);
		DrawPixel(x+i, y-i, R, G, B);
		DrawPixel(x+i, y+i, R, G, B);

		DrawPixel(x+(2*OPEN_SWITCH_SIZE)-i+1, y-i, R, G, B);
		DrawPixel(x+(2*OPEN_SWITCH_SIZE)-i+1, y+i, R, G, B);
		DrawPixel(x+(2*OPEN_SWITCH_SIZE)-i, y-i, R, G, B);
		DrawPixel(x+(2*OPEN_SWITCH_SIZE)-i, y+i, R, G, B);
	}

}

void opening_switch_rendering(cabin * cb)
{

	int x, y, y_erase;

	x = 100+(cb->id)*SPACE_BETWEEN_CABIN;
	y = 450 - CABIN_MOV_INCREMENT(cb->micro_position);

	y_erase = cb->previous_y;

	// on efface le bouton d'avant
	if (y_erase != -1)
		opening_switch_draw(x+2, y_erase-10,  0, 0, 0);

	if (cb->opening_button)
		opening_switch_draw(x+2, y-10, DOOR_COLOR);
	else
		opening_switch_draw(x+2, y-10, IVORY);
}

void cabin_rendering(cabin * cb)
{

	int x, y, x_loc, y_loc, i, bound;

	x = 100+(cb->id)*SPACE_BETWEEN_CABIN;
	y = 450 - CABIN_MOV_INCREMENT(cb->micro_position);

	// Attention, ne pas renverser ordre car la mise à jour de cb->y_prev
	// est effectuée par door_rendering
	opening_switch_rendering(cb);
	door_rendering(cb, x, y);


	// on barre la cabine d'une croix noire si frozen
	if(cb->accepting_ext_calls == 0)
	{

		x_loc = x - LOCK_POS * DOOR_LINE_PER_STEP;

		bound = LOCK_POS * DOOR_LINE_PER_STEP;

		for(i = 0 ; i < bound ; i++)
		{
			y_loc = i * DOOR_HEIGHT / bound;

			DrawPixel(x_loc +i, y - y_loc, BLACK);
			DrawPixel(x_loc +i, y - DOOR_HEIGHT + y_loc, BLACK);

		}


	}

}

#endif

int first_in_current_dir(cabin * cb)
{
	int i = cb->macro_position.quot;

	// si on monte l'étage suivant est i++
	// si on descend c'est i
	if (cb->dir_state == cabin_going_up)
		i++;

	while(1)
	{
		if (cb->internal_calls[i].called)
			return i;

		i = i + cb->dir_state;
	}
}

int cabin_trans_waiting_to_going(cabin * cb)
{

	// Hyp : cabine en  état waiting à un étage n
	// on calcule la date low_date_up du plus récent parmi les appels en haut
	// on calcule la date low_date_down du plus récent parmi les appels en bas
	// on part dans la direction du plus récent des deux



	int i;
	double low_date_up = UINT_MAX;
	double low_date_down = UINT_MAX;

	// GUARDS
	//GUARD(cbl->dir_state == cabin_waiting);


	for(i = cb->macro_position.quot ; i < NB_FLOORS ; i++ )
	{
		if (cb->internal_calls[i].date < low_date_up)
			low_date_up = cb->internal_calls[i].date;
	}

	for(i = cb->macro_position.quot ; i >= 0 ; i-- )
	{
		if (cb->internal_calls[i].date < low_date_down)
			low_date_down = cb->internal_calls[i].date;
	}

	// changement d'état

	if (low_date_up != low_date_down)
	{
		if (low_date_up < low_date_down)
		{
			cb->dir_state =  cabin_going_up;
			cb->ts_4_dir_state = cabin_tl_from_going_up;

		}
		else
		{
			cb->dir_state = cabin_going_down;
			cb->ts_4_dir_state = cabin_tl_from_going_down;
		}


		fprintf(TRACE_FILE,"cabin(%d) internal_cabin_trans_waiting_to_going:%s\n",cb->id, cb->dir_state == cabin_going_up ? "up" : "down");


		return 1;
	}

	// si pas de changement du aux appels internes
	// en second lieu on fait la même analyse
	// pour les appels externes

	low_date_up = UINT_MAX;
	low_date_down = UINT_MAX;

	for(i = cb->macro_position.quot ; i < NB_FLOORS ; i++ )
	{
		if (ext_calls_votes[i] == cb->id)
			if (ext_calls_dates[i] < low_date_up)
				low_date_up = ext_calls_dates[i];
	}

	for(i = cb->macro_position.quot ; i >= 0 ; i-- )
	{
		if (ext_calls_votes[i] == cb->id)
			if (ext_calls_dates[i] < low_date_down)
				low_date_down = ext_calls_dates[i];
	}

	// changement d'état

	if (low_date_up != low_date_down)
	{
		if (low_date_up < low_date_down)
		{
			cb->dir_state =  cabin_going_up;
			cb->ts_4_dir_state = cabin_tl_from_going_up;

		}
		else
		{
			cb->dir_state = cabin_going_down;
			cb->ts_4_dir_state = cabin_tl_from_going_down;
		}


		fprintf(TRACE_FILE,"cabin(%d) external_cabin_trans_waiting_to_going:%s\n",cb->id, cb->dir_state == cabin_going_up ? "up" : "down");


		return 1;
	}


	return 0;


}



int cabin_trans_going_down_to_waiting(cabin * cb)
{

	int i;

	// guards
	GUARD(cb->mov_state == cabin_stoped);


	for(i = cb->macro_position.quot - 1 ; i >= 0 ; i-- )
	{
		if (cb->internal_calls[i].called || ext_calls_votes[i] == cb->id)
			return 0;
	}


	cb->dir_state = cabin_waiting;
	cb->ts_4_dir_state = cabin_tl_from_waiting;

	fprintf(TRACE_FILE,"cabin(%d) cabin_trans_going_down_to_waiting\n", cb->id);

	return 1;
}

int cabin_trans_going_up_to_waiting(cabin * cb)
{

	int i;

	// guards
	GUARD(cb->mov_state == cabin_stoped);

	for(i = cb->macro_position.quot + 1 ; i < NB_FLOORS ; i++ )
	{
		if (cb->internal_calls[i].called || ext_calls_votes[i] == cb->id)
			return 0;
	}

	cb->dir_state = cabin_waiting;
	cb->ts_4_dir_state = cabin_tl_from_waiting;

	fprintf(TRACE_FILE,"cabin(%d) cabin_trans_going_up_to_waiting\n", cb->id);

	return 1;
}


/* TRANS MOV */


int cabin_trans_stoped_to_stoped(cabin * cb)
{


	// reset ext_call
	ext_calls_votes[cb->macro_position.quot] = NOT_A_FLOOR;
	ext_calls_dates[cb->macro_position.quot] = UINT_MAX;

	reset_internal_call(cb->id, & cb->internal_calls[cb->macro_position.quot]);

	return 0;
}


int cabin_trans_stoped_to_mov(cabin * cb)
{


	// guards
	GUARD(cb->door->ds == mov_enabled);
	GUARD(cb->dir_state != cabin_waiting)

	// TODO GUARD(cbl->time_closure > DELAY);

	cb->mov_state = (cb->dir_state == cabin_going_up) ? cabin_moving_up : cabin_moving_down;

	fprintf(TRACE_FILE,"cabin(%d) cabin_trans_stoped_to_mov, cbl->mov_state: %s\n", cb->id, cb->mov_state == cabin_moving_up ? "up" : "down");

	cb->ts_4_mov_state = cabin_tl_from_mov;

	return 1;

}

int cabin_trans_mov_leaving(cabin * cb)
{

	int delta;

	GUARD(cb->last_stop != NOT_A_FLOOR)

	delta = ((int) cb->micro_position) - cb->last_stop;
	if (delta < 0)
		delta = -delta;

	if(delta < LEAVING_THRESHOLD)
	{
		cb->speed = 0.5;

	}
	else
	{
		cb->speed = 1;
		cb->last_stop = NOT_A_FLOOR;

	}

	return 0;
}

int cabin_trans_mov_speed_reaching(cabin * cb)
{

	int delta;

	GUARD(cb->target_floor != NOT_A_FLOOR)

	delta = ((int) cb->micro_position) - (cb->target_floor * GRANULOSITE);

	if (delta < 0)
		delta = -delta;

	GUARD(delta <= SLOWING_THRESHOLD)

	cb->speed = 0.5;

	return 0;
}

int cabin_trans_mov_new_target(cabin * cb)
{

	int target;

	// REQ 13
	if ((cb->macro_position.rem > ACCEPTING_THRESHOLD) && (cb->macro_position.rem < (GRANULOSITE-ACCEPTING_THRESHOLD)))
	{

		target = first_in_current_dir(cb);

		if (target != cb->target_floor)
		{
			cb->target_floor = target;
			fprintf(TRACE_FILE,"cabin(%d): target is now floor %d\n",cb->id, cb->target_floor);
		}
	}

	return 0;

}

int cabin_trans_mov_to_mov(cabin * cb)
{

	int incr;

	cb->cumul_speed = cb->cumul_speed + cb->speed;

	if (floor(cb->cumul_speed) == 1)
	{
		incr = 1;
		cb->cumul_speed = 0;

	}
	else
		incr = 0;

	if (cb->mov_state == cabin_moving_up)
		cb->micro_position = cb->micro_position + incr;

	if (cb->mov_state == cabin_moving_down)
		cb->micro_position = cb->micro_position - incr;

	cb->macro_position = div(cb->micro_position, GRANULOSITE);

	if (cb->macro_position.rem == 0)
		fprintf(TRACE_FILE,"cabin(%d) cbl->macro_position:%d\n",cb->id, cb->macro_position.quot);
	else
		fprintf(TRACE_FILE,"cabin(%d) cbl->micro_position:%d\n", cb->id, cb->micro_position);

	return 0;

}

int cabin_trans_mov_to_stoped(cabin * cb)
{

	GUARD(cb->macro_position.rem == 0);

	// SANS REQ 13
	//GUARD(cb->internal_calls[cb->macro_position.quot].called || (ext_calls_votes[cb->macro_position.quot] == cb->id))

	// REQ 13
	GUARD((cb->target_floor == cb->macro_position.quot) || (ext_calls_votes[cb->macro_position.quot] == cb->id))

	cb->mov_state = cabin_stoped;
	cb->last_stop = cb->micro_position;
	fprintf(TRACE_FILE,"cabin(%d) cabin_trans_mov_to_stoped, target_floor was: %d, stoped at %d\n", cb->id, cb->target_floor, cb->macro_position.quot);
	cb->target_floor = NOT_A_FLOOR;
	cb->ts_4_mov_state = cabin_tl_from_stoped;

	return 1;

}





void cabin_trans_init(cabin * cb)
{

	int i;

	for(i = 0 ; i < NB_FLOORS ; i++)
	{
		(cb->internal_calls[i]).called = 0;
		(cb->internal_calls[i]).floor = i;
		(cb->internal_calls[i]).date = UINT_MAX;
	}

	cb->speed = 1;

	cb->cumul_speed = 0;

	cb->opening_button = 0;

	cb->accepting_ext_calls = 1;

	cb->dir_state = cabin_waiting;

	cb->mov_state = cabin_stoped;

	cb->micro_position = 0;

	cb->last_stop = cb->micro_position;

	cb->macro_position = div((int) cb->micro_position, GRANULOSITE);

	cb->ts_4_dir_state = cabin_tl_from_waiting;

	cb->ts_4_mov_state = cabin_tl_from_stoped;

	cb->door = RESERVER(1,door);

	door_init_trans(cb->door);

	cb->door->cb = cb;

	cb->target_floor = NOT_A_FLOOR;

#ifdef ELEVATOR_RENDERING
	cb->previous_y = -1;
#endif

}


void cabin_ts_init(void)
{

	// dir state transitions lists
	cabin_tl_from_waiting = new_trans_list();
	trans_list_push_back(cabin_tl_from_waiting, &cabin_trans_waiting_to_going);

	cabin_tl_from_going_down = new_trans_list();
	trans_list_push_back(cabin_tl_from_going_down,&cabin_trans_going_down_to_waiting);

	cabin_tl_from_going_up = new_trans_list();
	trans_list_push_back(cabin_tl_from_going_up,&cabin_trans_going_up_to_waiting);



	// move state transitions lists
	cabin_tl_from_stoped  = new_trans_list();
	trans_list_push_back(cabin_tl_from_stoped,&cabin_trans_stoped_to_stoped);
	trans_list_push_back(cabin_tl_from_stoped,&cabin_trans_stoped_to_mov);


	cabin_tl_from_mov = new_trans_list();
	trans_list_push_back(cabin_tl_from_mov,&cabin_trans_mov_to_mov);
	trans_list_push_back(cabin_tl_from_mov,&cabin_trans_mov_leaving);
	trans_list_push_back(cabin_tl_from_mov,&cabin_trans_mov_new_target);
	trans_list_push_back(cabin_tl_from_mov,&cabin_trans_mov_speed_reaching);
	trans_list_push_back(cabin_tl_from_mov,&cabin_trans_mov_to_stoped);



}

void reset_internal_call(int id, cabin_call * cc)
{
	if (cc->called)
	{
		cc->called = 0;
		cc->date = UINT_MAX;

		fprintf(TRACE_FILE,"cabin(%d) reset_internal_call:%d\n",id, cc->floor);
	}
}

void flush_ext_calls(cabin * cb)
{

	int i;

	for(i = 0 ; i < NB_FLOORS ; i++)
	{

		if (ext_calls_votes[i] == cb->id)
		{
			// on dé-attribue la cabine à l'étage i
			ext_calls_votes[i] =  NOT_A_FLOOR;

			// on replace l'étage i dans la pile d'appels externes
			push_ext_call(i);
		}


	}



}

void cabin_execution_step(cabin * cb)
{
	int exec = 0;
	trans_elem * trans;

	fprintf(TRACE_FILE,"cabin simulation (%d):\n", cb->id);

	// en premier lieu on simule la porte ...
	door_simulation(cb->door);

	// ... puis le mouvement de la cabine
	trans = cb->ts_4_mov_state->first;

	while ((! exec) && trans)
	{
		exec = trans->trans_func(cb);
		trans = trans->next;
	}

	// ... puis on actualise l'état logique de direction
	exec = 0;
	trans = cb->ts_4_dir_state->first;

	while ((! exec) && trans)
	{
		exec = trans->trans_func(cb);
		trans = trans->next;
	}

	// ... puis on actualise l'état d'acceptation
	// des appels externes

	if (cb->door->ttly_open_since >= FREEZE_DELAY && cb->opening_button)
	{
		cb->accepting_ext_calls = 0;

		// REQ 8
		flush_ext_calls(cb);

		fprintf(TRACE_FILE,"cabin(%d) freezed\n",cb->id);
	}

	if (! cb->opening_button)
		cb->accepting_ext_calls = 1;


}

