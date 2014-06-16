/*
 * door.c
 *
 *  Created on: 7 mars 2011
 *      Author: rapin  CEA LIST
 */

#include "door.h"
#include "macros.h"



#ifdef ELEVATOR_RENDERING

void door_erase_previous_pos(cabin * cb, int x, int y)
{

	int y_erase_start, y_erase_end, x_loc, bound, i , j;

	if (cb->previous_y == -1)
	{
		cb->previous_y = y;
	}

	if (y == cb->previous_y)
		return;

	if (y < cb->previous_y)
	{
		y_erase_start = y+1;
		y_erase_end = cb->previous_y+1;
	}
	else
	{
		y_erase_start = cb->previous_y - DOOR_HEIGHT + 1;
		y_erase_end = y - DOOR_HEIGHT + 1;
	}

	x_loc = x - LOCK_POS * DOOR_LINE_PER_STEP;
	bound = LOCK_POS * DOOR_LINE_PER_STEP;

	for(i = 0 ; i < bound ; i++ )
	{
		for(j = y_erase_start ; j < y_erase_end ; j ++)
		{
			DrawPixel(x_loc+i, j, BLACK);

		}
	}

	cb->previous_y = y;

}

void door_rendering(cabin * cb, int x, int y)
{

	int i, j, bound;
	int x_loc;
	door * d = cb->door;

	door_erase_previous_pos(cb, x, y);

	x_loc = x - LOCK_POS * DOOR_LINE_PER_STEP; // DOOR_LINE_PER_STEP lignes par step d'ouverture

	// affichage de la porte
	bound = d->pos * DOOR_LINE_PER_STEP;

	for(i = 0 ; i < bound ; i++ )
	{
		for(j = 0 ; j < DOOR_HEIGHT ; j ++)
		{
			DrawPixel(x_loc+i, y-j, DOOR_COLOR);

		}
	}

	// affichage du fond de cabine (partie non couverte par la porte)
	bound = LOCK_POS * DOOR_LINE_PER_STEP;

	for( ; i < bound ; i++)
	{
		for(j = 0 ; j < DOOR_HEIGHT ; j ++)
		{
			DrawPixel(x_loc+i, y-j, 255, 255, 255);

		}

	}

}

#endif /* ELEVATOR_RENDERING */

void door_init_trans(door * d)
{

	d->pos = 0;
	d->ds = totally_open;
	d->tl = door_tl_from_totally_open;
	d->ttly_open_since = 0;
	d->ttly_closed_since = 0;

}


int door_trans_opening_to_ttly_open(door * d)
{

	 GUARD(d->pos == 0)

	 d->ds = totally_open;
	 d->tl = door_tl_from_totally_open;

	 fprintf(TRACE_FILE,"cabin (%d) : door ttly open\n",d->cb->id);

	 return 1;

}

int door_trans_opening_to_opening(door * d)
{

	 GUARD(d->pos > 0)

	 d->pos--;

	 fprintf(TRACE_FILE,"cabin (%d) : door is opening\n",d->cb->id);

	 return 1;

}


int door_trans_mov_enabled_to_opening(door * d)
{

	 GUARD(d->cb->mov_state == cabin_stoped);

	 d->ds = opening;
	 d->tl = door_tl_from_opening;

	 fprintf(TRACE_FILE,"cabin (%d) : door opening starts\n",d->cb->id);

	 return 1;
}

int door_trans_ttly_open_to_ttly_open(door * d)
{

	d->ttly_open_since++;

	fprintf(TRACE_FILE,"cabin (%d) : door ttly open since %d\n",d->cb->id, d->ttly_open_since);

	return 0;
}

int door_trans_ttly_open_to_closing(door * d)
{

	 GUARD(d->cb->dir_state != cabin_waiting && (! d->cb->opening_button));

	 d->ds = closing;
	 d->ttly_open_since = 0;
	 d->tl = door_tl_from_closing;

	 fprintf(TRACE_FILE,"cabin (%d) : door closing starts\n",d->cb->id);

	 return 1;
}

int door_trans_closing_to_closing(door * d)
{


	 GUARD(d->pos < LOCK_POS && (!d->cb->opening_button))

	 d->pos++;

	 fprintf(TRACE_FILE,"cabin (%d) : door is closing\n",d->cb->id);

	 return 1;

}

int door_trans_closing_to_opening(door * d)
{

	 GUARD(d->pos < LOCK_POS && d->cb->opening_button)

	 d->ds = opening;
	 d->tl = door_tl_from_opening;

	 fprintf(TRACE_FILE,"cabin (%d) : door switch from closing to opening\n",d->cb->id);

	 return 1;

}

int door_trans_closing_to_ttly_closed(door * d)
{

	 GUARD(d->pos == LOCK_POS)

	 d->ds = totally_closed;
	 d->ttly_closed_since = 0;

	 d->tl = door_tl_from_totally_closed;

	 fprintf(TRACE_FILE,"cabin (%d) : door ttly closed\n",d->cb->id);

	 return 1;

}

int door_trans_ttly_closed_to_ttly_closed(door * d)
{
	GUARD(d->ttly_closed_since < MOVE_DELAY)

	d->ttly_closed_since++;

	fprintf(TRACE_FILE,"cabin (%d) : door closed, waiting ...\n",d->cb->id);

	return 0;
}

int door_trans_ttly_closed_to_opening(door * d)
{
	GUARD(d->ttly_closed_since < MOVE_DELAY && d->cb->opening_button);

	d->ds = opening;

	d->tl = door_tl_from_opening;

	fprintf(TRACE_FILE,"cabin (%d) : open_button pressed\n",d->cb->id);

	return 1;
}

int door_trans_ttly_closed_to_mov_enabled(door * d)
{

	GUARD(d->ttly_closed_since == MOVE_DELAY)

	d->ttly_closed_since = 0;
	d->ds = mov_enabled;
	d->tl = door_tl_from_start_enabled;

	fprintf(TRACE_FILE,"cabin (%d) : door closed, move enabled\n",d->cb->id);

	return 1;

}

void door_ts_init()
{

	door_tl_from_opening = new_trans_list();
	trans_list_push_back(door_tl_from_opening, &door_trans_opening_to_opening);
	trans_list_push_back(door_tl_from_opening, &door_trans_opening_to_ttly_open);


	door_tl_from_totally_closed = new_trans_list();
	trans_list_push_back(door_tl_from_totally_closed, &door_trans_ttly_closed_to_ttly_closed);
	trans_list_push_back(door_tl_from_totally_closed, &door_trans_ttly_closed_to_opening);
	trans_list_push_back(door_tl_from_totally_closed, &door_trans_ttly_closed_to_mov_enabled);

	door_tl_from_totally_open = new_trans_list();
	trans_list_push_back(door_tl_from_totally_open,&door_trans_ttly_open_to_ttly_open);
	trans_list_push_back(door_tl_from_totally_open,&door_trans_ttly_open_to_closing);


	door_tl_from_closing = new_trans_list();
	trans_list_push_back(door_tl_from_closing,&door_trans_closing_to_closing);
	trans_list_push_back(door_tl_from_closing,&door_trans_closing_to_opening);
	trans_list_push_back(door_tl_from_closing,&door_trans_closing_to_ttly_closed);

	door_tl_from_start_enabled = new_trans_list();
	trans_list_push_back(door_tl_from_start_enabled, &door_trans_mov_enabled_to_opening);
}

void door_simulation(door * d)
{

	int exec = 0;
	trans_elem * trans;

	trans = d->tl->first;

	while ((! exec) && trans)
	{
		exec = trans->trans_func(d);
		trans = trans->next;
	}

}
