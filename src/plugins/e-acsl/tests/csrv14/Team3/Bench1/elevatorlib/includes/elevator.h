/*
 * elevator.h
 *
 *  Created on: 10 févr. 2011
 *      Author: rapin  CEA LIST
 */

#ifndef ELEVATOR_H_
#define ELEVATOR_H_

#ifdef ELEVATOR_RENDERING
#include "SDL.h"
#include "SDL_ttf.h"
#endif /*ELEVATOR_RENDERING */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

unsigned sim_duration;
unsigned sim_speed;

#define IS_INT(x) ((((int) x) - floor(x)) == 0)
#define NB_CABINS 3
#define NB_FLOORS 12
#define NOT_A_FLOOR  -1
#define TRACE_FILE stdout
#define FREEZE_DELAY 30
#define GRANULOSITE 10
#define ACCEPTING_THRESHOLD 2
#define SLOWING_THRESHOLD 2
#define LEAVING_THRESHOLD 2

#ifdef ELEVATOR_RENDERING
TTF_Font *police;
SDL_Surface * screen;
void DrawPixel(int x, int y, Uint8 R, Uint8 G, Uint8 B);
void elevator_rendering(int date);
void elevator_rendering_init();
void elevator_rendering_close();
#define DOOR_LINE_PER_STEP 4
#define DOOR_HEIGHT 30
#define CABIN_MOV_INCREMENT(x) ((x*DOOR_HEIGHT) / GRANULOSITE)
#define ELAPSE_COLOR 15000000
#define DOOR_COLOR 192,0,0
#define IVORY 255,255,240
#define YELLOW 255,255,0
#define BLACK 0,0,0
#define GRAY 198,226,255
#define COUNTER_X_POS 500
#define COUNTER_Y_POS 40
#define OPEN_SWITCH_SIZE 6
#define SPACE_BETWEEN_CABIN 70
#endif // ELEVATOR_RENDERING


typedef struct cabin_ cabin;
typedef struct ext_call_ ext_call;
typedef struct cabin_door_ cabin_door;
typedef struct cabin_call_ cabin_call;
typedef struct door_ door;



void elevator_execution_step(unsigned date);

void terminate_elevator_simulation(unsigned date);

void sleep(int nbr_milli_seconds);

void elevator_init(unsigned,unsigned);
void push_ext_call(int);

void internal_call_func(int id_cabin, int floor, unsigned step);
void run_until_to_func(unsigned nb_step, unsigned * i);
void press_open_func(int cb_id);
void relax_open_func(int cb_id);
void run_func(unsigned * i);

#define DISPLAY_BANNER fprintf(TRACE_FILE,"\n-----------------  Début de la Simulation ------------------------\n"); fprintf(TRACE_FILE,"\nNombre de pas de simulation: %d\n",sim_duration)

#define INTERN_CALL(c,f,t) internal_call_func(c,f,t)

#define RUN_UNTIL(n,i) run_until_to_func(n,&i)

#define EXT_CALL(n) push_ext_call(n)

#define  PRESS_OPEN_SWITCH(c) press_open_func(c)

#define  RELAX_OPEN_SWITCH(c) relax_open_func(c)

#define RUN(i) run_func(&i)

#define END(i) terminate_elevator_simulation(++i); sleep(1500)

#endif /* ELEVATOR_H_ */
