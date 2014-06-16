/*
 * macros.h
 *
 *  Created on: 8 févr. 2011
 *      Author: rapin  CEA LIST
 */


#include <stdio.h>

#ifndef MACROS_H_
#define MACROS_H_



#define RESERVER(x,y) (y *) malloc(sizeof(y)*x);
#define RESERVERN(x,y) (y *) calloc(x,sizeof(y));
#define LIBERER(x,y,z) free(z);


#endif /* MACROS_H_ */
