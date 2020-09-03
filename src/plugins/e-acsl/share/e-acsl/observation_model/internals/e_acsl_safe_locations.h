/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2020                                               */
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
 * Declaration of memory locations considered safe before a program starts.
 * Most of these should be declared somewhere in start procedures of c
 * and gcc libraries. One example of a safe location is errno.
***************************************************************************/

#ifndef E_ACSL_SAFE_LOCATIONS_H
#define E_ACSL_SAFE_LOCATIONS_H

#include <stdint.h>
#include <stddef.h>

/* Simple representation of a safe location */
struct memory_location {
  uintptr_t address; /* Address */
  uintptr_t length; /* Byte-length */
  int is_initialized; /* Notion of initialization */
};
typedef struct memory_location memory_location;

/*! Initialize the array of safe locations */
void collect_safe_locations();

/*! \return the number of safe locations collected */
size_t get_safe_locations_count();

/*! \return The i-th safe location collected */
memory_location * get_safe_location(size_t i);

#endif // E_ACSL_SAFE_LOCATIONS_H
