/*
 * main.c
 *
 *  Created on: 8 février. 2011
 *      Author: rapin CEA LIST
 */

#include "elevator.h"

//int main(int argc, char *argv[])
int main(void)
{

	int i = 0;
	int date = 0;

	// INITIALISATION
	elevator_init(390,500); // l'argument est le nombre de pas de simulation

	INTERN_CALL(1,2,date);
	INTERN_CALL(1,5,date);
	INTERN_CALL(1,0,date);


	// SIMULATION
	DISPLAY_BANNER;

	RUN_UNTIL(23,i);

	INTERN_CALL(1,8,date++);
	INTERN_CALL(2,4,date++);

	RUN_UNTIL(27,i);
	PRESS_OPEN_SWITCH(2);

	RUN_UNTIL(29,i);
	RELAX_OPEN_SWITCH(2);

	EXT_CALL(3);

	RUN_UNTIL(124,i);

	//INTERN_CALL(1,4,date++);
	INTERN_CALL(1,1,date++);

	PRESS_OPEN_SWITCH(1);

	INTERN_CALL(2,3,date++);

	RUN_UNTIL(214,i);

	EXT_CALL(9);

	RUN(i);
	RUN(i);

	RELAX_OPEN_SWITCH(1);

	RUN_UNTIL(230,i);

	INTERN_CALL(3,7,date++);


	PRESS_OPEN_SWITCH(1);

	RUN(i);
	RUN(i);

	RELAX_OPEN_SWITCH(1);

	RUN_UNTIL(270,i);

	EXT_CALL(4);

	RUN_UNTIL(sim_duration,i);

	END(i);

	return 0;


}
