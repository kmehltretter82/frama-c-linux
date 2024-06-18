/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2024                                               */
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

/*! ***********************************************************************
 * \file
 *
 * Declaration of memory locations considered safe (= allocated) before a
 * program starts. Most of these should be declared somewhere in start
 * procedures of c and gcc libraries. One example of a safe location is errno.
 * These memory locations are not (necessarily) in any of the segments.
 **************************************************************************/

#ifndef E_ACSL_SAFE_LOCATIONS_H
#define E_ACSL_SAFE_LOCATIONS_H

#include <stddef.h>
#include <stdint.h>

/*! Simple representation of a safe location */
struct memory_location {
  const char *name;
  uintptr_t address;
  uintptr_t length; /* in bytes */
  int initialized;
  int writeable;
  int freeable;
};
typedef struct memory_location memory_location;

/*! Initialize the array of safe locations */
void collect_safe_locations();

memory_location *get_safe_location(uintptr_t addr, long size);

int is_safe_location(uintptr_t addr, long size);

#endif // E_ACSL_SAFE_LOCATIONS_H
