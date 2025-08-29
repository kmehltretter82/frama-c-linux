/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

#ifndef __FC_GETOPT_H
#define __FC_GETOPT_H
#include "features.h"
__PUSH_FC_STDLIB
#include "unistd.h"
__BEGIN_DECLS


/* GNU specific */
struct option
{
  const char *name;
  int has_arg;
  int *flag;
  int val;
};

# define no_argument		0
# define required_argument	1
# define optional_argument	2


/*@ 
  assigns \result, *optarg, optind, opterr, optopt, *(longopts[0..].flag)
             \from argc, argv[0..argc-1], shortopts[0..], longopts[0..];
 */
extern int getopt_long (int argc, char *const argv[],
			const char *shortopts,
			const struct option *longopts, int *longind);

/*@ 
  assigns \result, *optarg, optind, opterr, optopt, *(longopts[0..].flag)
             \from argc, argv[0..argc-1], shortopts[0..], longopts[0..];
 */
extern int getopt_long_only (int argc, char *const argv[],
			     const char *shortopts,
			     const struct option *longopts, int *longind);

__END_DECLS

__POP_FC_STDLIB
#endif
