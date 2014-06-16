/*
 * elevator.c
 *
 *  Created on: 7 mars 2011
 *      Author: rapin CEA LIST
 */


#include "ext_call.h"
#include "cabin.h"
#include "door.h"

#ifdef ARTIMON
#include "artimon.h"
#endif

#define TOTO
#define ATOMIZE(x) ((x) ? (int) 1 : (int) 0)

enum atoms
{
	false,
	time_is_zero,
	door_1_open,
	door_1_ttly_open,
	cabin_1_stoped,
	cabin_1_waiting,
	cabin_1_called,
	cabin_1_opening_button_pressed,
	cabin_1_accepting_ext_call,
	cabin_1_accepting_new_target,    // cb->pos assez loin d'un arrêt
	cabin_1_target_defined,
};

void elevator_init(unsigned sd, unsigned ss)
{

	int i;

#ifdef ARTIMON

	int nbat, nbsig;
	int nb_main;
	double * main_value_tab;

	// initialisation d'ARTiMon V_8
	// int init_artimon_4_simulators(char * config_name, int * nb_atoms, int * nb_sig, int StepMode, int * nb_main, double ** main_value_tab);

	init_artimon_4_simulators("elevator", &nbat, &nbsig, 0, & nb_main, & main_value_tab);

#endif

#ifdef ELEVATOR_RENDERING

	elevator_rendering_init(sd);

#endif

	// initialisations des structures

	sim_duration = sd;
	sim_speed = ss;

	// initialisation du tableau d'états des appels externes
	ext_calls_init();

	// creation du buffer d'appels externes
	ext_calls_buffer = RESERVER(1,struct ext_call_stack);
	ext_calls_buffer->first = ext_calls_buffer->last = NULL;

	// creation des systèmes de transitions pour : cabine, porte
	cabin_ts_init();
	door_ts_init();


	// creation d'instances de cabines

	cabin * cb;

	for(i = 0 ; i < NB_CABINS ; i++)
	{
		cb = RESERVER(1,cabin);
		cabin_trans_init(cb);
		cb->id = i+1;
		cabins[i] = cb;
	}


	if (NB_CABINS >1 )
	{
		fprintf(TRACE_FILE,"cabin(2) : initialisée à l'étage 5\n");
		cabins[1]->micro_position = 5 * GRANULOSITE;
		cabins[1]->last_stop = cabins[1]->micro_position;
		cabins[1]->macro_position = div(cabins[1]->micro_position, GRANULOSITE);
	}

}


int cabin_called(cabin * cb)
{
	int i;

	for(i = 0 ; i < NB_FLOORS ; i++)
	{
		if (cb->internal_calls[i].called || ext_calls_votes[i] == cb->id)
			return 1;
	}

	return 0;


}

#ifdef ARTIMON

void call_to_artimon(unsigned date)
{

		int signal = 0;
		unsigned sigtab[2];
		double d;

		artimon_refresh_atom(false,0);
		artimon_refresh_atom(time_is_zero,ATOMIZE(date == 0));
		artimon_refresh_atom(door_1_open,ATOMIZE(cabins[0]->door->ds == opening || cabins[0]->door->ds == totally_open));
		artimon_refresh_atom(door_1_ttly_open,ATOMIZE(cabins[0]->door->ds == totally_open));
		artimon_refresh_atom(cabin_1_stoped,ATOMIZE(cabins[0]->mov_state == cabin_stoped));
		artimon_refresh_atom(cabin_1_waiting,ATOMIZE(cabins[0]->dir_state == cabin_waiting));
		artimon_refresh_atom(cabin_1_called,cabin_called(cabins[0]));
		artimon_refresh_atom(cabin_1_opening_button_pressed,ATOMIZE(cabins[0]->opening_button == 1));
		artimon_refresh_atom(cabin_1_accepting_ext_call,ATOMIZE(cabins[0]->accepting_ext_calls == 1));
		artimon_refresh_atom(cabin_1_accepting_new_target,ATOMIZE(((cabins[0]->macro_position.rem > ACCEPTING_THRESHOLD) && (cabins[0]->macro_position.rem < (GRANULOSITE-ACCEPTING_THRESHOLD)))));
		artimon_refresh_atom(cabin_1_target_defined,ATOMIZE(cabins[0]->target_floor != NOT_A_FLOOR));


		d = (double) cabins[0]->dir_state;
		sigtab[0] = (* ((unsigned *) &d));
		sigtab[1] = (*(((unsigned *) &d) + 1));
		artimon_refresh_signal(signal++, sigtab);

		d = (double) cabins[0]->micro_position;

		sigtab[0] = (* ((unsigned *) &d));
		sigtab[1] = (*(((unsigned *) &d) + 1));
		artimon_refresh_signal(signal++, sigtab);

		d = (double) (cabins[0]->target_floor * GRANULOSITE);

		sigtab[0] = (* ((unsigned *) &d));
		sigtab[1] = (*(((unsigned *) &d) + 1));
		artimon_refresh_signal(signal++, sigtab);


		d = date;

		artimon_refresh_time(d);

}
#endif



void elevator_execution_step(unsigned date)
{

	int nbc;

#ifdef ARTIMON
	call_to_artimon(date);
#endif

	ext_call_cabin_assignation(date);

	for(nbc = 0 ; nbc < NB_CABINS ; nbc++)
	{
		cabin_execution_step(cabins[nbc]);
	}



	fflush(stdout);

#ifdef ELEVATOR_RENDERING
	sleep(sim_speed/GRANULOSITE);
	elevator_rendering(date);
#endif /* ELEVATOR_RENDERING */


}

void terminate_elevator_simulation(unsigned date)
{

#ifdef ELEVATOR_RENDERING
	elevator_rendering_close();
	TTF_CloseFont(police);
	TTF_Quit();
#endif /* ELEVATOR_RENDERING */

#ifdef ARTIMON
	call_to_artimon(date);
	close_artimon_4_simulators();
#endif


}
