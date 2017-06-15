/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2017                                               */
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
 * \file   e_acsl_floating_point.h
 * \brief  Functionality related to processing of floating point values
***************************************************************************/

#ifndef E_ACSL_FLOATING_POINT_H
#define E_ACSL_FLOATING_POINT_H

#include "e_acsl_mmodel_api.h"
#include <math.h>
#include <float.h>

/* Below variables hold infinity values for floaing points defined in math.h.
   Most of them are defined as macros that expand to built-in function calls.
   As such, they cannot be used in E-ACSL specifications directly. To solve
   the issue this header provides alternative definitions prefixed
   __e_acsl_math_. For instance, if a call to `pow` overflows it
   returns `HUGE_VAL`. To make sure that the result of pow does not overflow
   one can use the following assertion

     extern double __e_acsl_math_HUGE_VAL;
     ...
     double x = 500000000.0;
     double y = 500000000.0;
     double z = pow(x,y);
     //@assert z != 0.0 && z != __e_acsl_math_HUGE_VAL;
*/

/** \brief Positive infinity for doubles: same as HUGE_VAL */
double math_HUGE_VAL = 0.0;
/** \brief Positive infinity for floats: same as HUGE_VALF */
float  math_HUGE_VALF = 0.0;
/** \brief Positive infinity for long doubles: same as HUGE_VALL */
long double math_HUGE_VALL = 0.0;
/** \brief Representation of infinity value for doubles: same as INFINITY */
double math_INFINITY = 0.0;

/* Initialize E-ACSL infinity values */
static void init_infinity_values() {
  math_HUGE_VAL = HUGE_VAL;
  math_HUGE_VALF = HUGE_VALF;
  math_HUGE_VALL = HUGE_VALL;
  math_INFINITY = INFINITY;
}

#endif
