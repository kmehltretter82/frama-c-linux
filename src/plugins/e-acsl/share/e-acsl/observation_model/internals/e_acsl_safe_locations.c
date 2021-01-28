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

#include <stdio.h>
#include <errno.h>

#include "../../internals/e_acsl_config.h"
#include "e_acsl_safe_locations.h"

/* An array storing safe locations up to `safe_location_counter` position.
 * This array should be initialized via a below function called
 * `collect_safe_locations`. */
static memory_location safe_locations [16];
static int safe_location_counter = 0;

#define add_safe_location(_addr,_len,_init,_on_static) do { \
  safe_locations[safe_location_counter].address = _addr; \
  safe_locations[safe_location_counter].length = _len; \
  safe_locations[safe_location_counter].is_initialized = _init; \
  safe_locations[safe_location_counter].is_on_static = _on_static; \
  safe_location_counter++; \
} while (0)

void collect_safe_locations() {
  /* Tracking of errno and standard streams */
  add_safe_location((uintptr_t)&errno, sizeof(int), 1, E_ACSL_OS_IS_LINUX);
  add_safe_location((uintptr_t)stdout, sizeof(FILE), 1, E_ACSL_OS_IS_LINUX);
  add_safe_location((uintptr_t)stderr, sizeof(FILE), 1, E_ACSL_OS_IS_LINUX);
  add_safe_location((uintptr_t)stdin, sizeof(FILE), 1, E_ACSL_OS_IS_LINUX);
}

size_t get_safe_locations_count() {
  return safe_location_counter;
}

memory_location * get_safe_location(size_t i) {
  return &safe_locations[i];
}
