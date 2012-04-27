/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012                                                    */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  you can redistribute it and/or modify it under the terms of the GNU   */
/*  Lesser General Public License as published by the Free Software       */
/*  Foundation, version 2.1.                                              */
/*                                                                        */
/*  It is distributed in the hope that it will be useful,                 */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*  GNU Lesser General Public License for more details.                   */
/*                                                                        */
/*  See the GNU Lesser General Public License version 2.1                 */
/*  for more details (enclosed in the file licenses/LGPLv2.1).            */
/*                                                                        */
/**************************************************************************/

/************************/
/* Standard C functions */
/************************/

/*@ terminates \false;
  @ assigns \nothing;
  @ ensures \false; */
extern void exit(int status);

/*@ assigns \nothing; */
extern int printf(const char *, ...);

/*****************************/
/* Dedicated E-ACSL function */
/*****************************/

/*@ requires predicate != 0; 
  @ assigns \nothing; */
void e_acsl_assert(int predicate, char *kind, char *pred_txt, int line) {
  if (! predicate) {
    printf("%s failed at line %d.\nThe failing predicate is:\n%s.\n", 
	   kind, line, pred_txt); 
    exit(1);
  }
}
