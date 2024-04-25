/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2024                                               */
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

// Stub for a main function which reads arguments from the command line, to be
// used by the Eva plug-in.
// This stub emulates non-deterministic input of up to 5 arguments, each up
// to 256 characters long. This is sufficient to ensure arbitrary input in
// virtually every case.
// Do not forget to add option '-main eva_main' in order to use this stub.

#ifdef __FRAMAC__
# include "__fc_builtin.h"
int main(int, char **);
static volatile int nondet;
int eva_main() {
  int argc = Frama_C_interval(0, 5);
  char argv0[256], argv1[256], argv2[256], argv3[256], argv4[256];
  char *argv[6] = {argv0, argv1, argv2, argv3, argv4, 0};
  //@ loop unroll 5;
  for (int i = 0; i < 5; i++) {
    Frama_C_make_unknown(argv[i], 255);
    argv[i][255] = 0;
  }
  return main(argc, argv);
}
#endif // __FRAMAC__
