/*
 * utils.c
 *
 *  Created on: 14 mars 2011
 *      Author: rapin  CEA LIST
 */

#include <time.h>

void sleep(int nbr_milli_seconds)
{
	clock_t goal;

	goal =  nbr_milli_seconds + clock();

	while(goal > clock())
	{ ;}
}
