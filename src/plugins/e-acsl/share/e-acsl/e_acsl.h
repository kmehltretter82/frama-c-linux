/**************************************************************************/
/*                                                                        */
/*  This file is part of the E-ACSL plug-in of Frama-C.                   */
/*                                                                        */
/*  Copyright (C) 2011                                                    */
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

// TODO: remplacer par un e_acsl.h.in
// faire générer par le makefile un e_acsl.h
// avec des #include "FRAMAC_SHARE/libc/stdio.h", etc

// [TODO] ne pas générer les typedef si on veut linker avec GMP derrière

// [TODO] utiliser un champ modèle de type integer pour modéliser
// l'entier exact correspondant à un mpz_t.
// Not yet implemented in ACSL.

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

void e_acsl_fail(char *msg) { printf("%s\n", msg); exit(1); }
