/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

#include "unistd.h"
#include "__fc_builtin.h"
#include "string.h"
__PUSH_FC_STDLIB

volatile char __fc_hostname[HOST_NAME_MAX];
volatile char __fc_ttyname[TTY_NAME_MAX];
char __fc_crypt[256];
char __fc_getlogin[LOGIN_NAME_MAX];
char __fc_getpass[16];

int optind = 1;
char *optarg;
int opterr = 1; // initial value is not zero (zero silences error messages)

int getopt(int argc, char * const argv[], const char *optstring) {
  if (argc == 0) {
    return -1;
  }
  int nondet_ind = Frama_C_interval(1, argc - 1);
  int nondet_indlen = Frama_C_interval(0, strlen(argv[nondet_ind])-1);
  optarg = Frama_C_nondet_ptr(0, &argv[nondet_ind][nondet_indlen]);
  optind = Frama_C_interval(1, argc + 1);
  return Frama_C_nondet(-1, Frama_C_unsigned_char_interval(0, UCHAR_MAX));
}

__POP_FC_STDLIB
