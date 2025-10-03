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
#include "getopt.h"
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
  if (optind >= argc) {
    return -1;
  }
  int ind = Frama_C_interval(1, argc - 1);
  int len = strlen(argv[ind]);
  int arg = Frama_C_interval(0, len - 1);
  int opt = Frama_C_interval(arg+1, len - 1);

  // Move optind forward
  optind = Frama_C_interval(optind, argc);

  if (Frama_C_nondet(0, 1)) {
    // Normal case
    optarg = Frama_C_nondet_ptr(0, &argv[ind][arg]);
    return argv[ind][opt];
  }
  else if (Frama_C_nondet(0, 1)) {
    // No more characters
    return -1;
  }
  else {
    // Error case
    optopt = argv[ind][opt];
    return Frama_C_nondet('?', ':');
  }
}

int getopt_long (int argc, char *const argv[],
                 const char *optstring,
                 const struct option *longopts, int *longind) {
  if (optind >= argc) {
    return -1;
  }
  if (Frama_C_nondet(0, 1)) {
    // found short option
    int nondet_ind = Frama_C_interval(1, argc - 1);
    int nondet_indlen = Frama_C_interval(0, strlen(argv[nondet_ind])-1);
    optarg = Frama_C_nondet_ptr(0, &argv[nondet_ind][nondet_indlen]);
    optind = Frama_C_interval(1, argc + 1);
    return optstring[Frama_C_interval(0, strlen(optstring)-1)];
  }
  if (Frama_C_nondet(0, 1)) {
    // found long option; compute length of options array
    int n_longopts = 0;
    while (longopts[n_longopts].name != 0) { // note: in theory we should check
                                             // that all fields are 0
      n_longopts++;
    }
    int nondet_ind = Frama_C_interval(0, n_longopts-1);
    const struct option *p = &longopts[nondet_ind];
    if (longind) {
      *longind = nondet_ind;
    }
    int nondet_indlen = Frama_C_interval(0, strlen(argv[nondet_ind])-1);
    optarg = Frama_C_nondet_ptr(0, &argv[nondet_ind][nondet_indlen]);
    optind = nondet_ind;
    if (!p->flag) return p->val;
    else {
      /* from the manpage: "... flag points to a variable which is set to val
         if the option is found, but left unchanged if the option is not
         found" */
      if (Frama_C_nondet(0, 1)) {
        *(p->flag) = p->val;
      }
      return 0;
    }
  } else {
    if (Frama_C_nondet(0, 1)) {
      // all command-lines options have been parsed
      return -1;
    } else {
      // found option character not in optstring
      return optstring[0] == ':' ? ':' : '?';
    }
  }
}

int getopt_long_only(int argc, char *const argv[],
                     const char *optstring,
                     const struct option *longopts, int *longind) {
  return getopt_long(argc, argv, optstring, longopts, longind);
}

__POP_FC_STDLIB
