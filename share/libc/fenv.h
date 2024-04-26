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

/* ISO C: 7.6 */
#ifndef __FC_FENV
#define __FC_FENV
#include "features.h"
__PUSH_FC_STDLIB

__BEGIN_DECLS

/* Define bits representing the exception.  We use the bit positions
   of the appropriate bits in the FPU control word.  */
enum __fc_fe_error
  {
    FE_INVALID = 0x01,
#define FE_INVALID	FE_INVALID
    __FE_DENORM = 0x02,
    FE_DIVBYZERO = 0x04,
#define FE_DIVBYZERO	FE_DIVBYZERO
    FE_OVERFLOW = 0x08,
#define FE_OVERFLOW	FE_OVERFLOW
    FE_UNDERFLOW = 0x10,
#define FE_UNDERFLOW	FE_UNDERFLOW
    FE_INEXACT = 0x20
#define FE_INEXACT	FE_INEXACT
  };

#define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* Type representing floating-point environment.  This structure
   corresponds to the layout of the block written by the `fstenv'
   instruction and has additional fields for the contents of the MXCSR
   register as written by the `stmxcsr' instruction.  */
typedef struct __fc_fenv_t
  {
    unsigned short int __control_word;
    unsigned short int __unused1;
    unsigned short int __status_word;
    unsigned short int __unused2;
    unsigned short int __tags;
    unsigned short int __unused3;
    unsigned int __eip;
    unsigned short int __cs_selector;
    unsigned int __opcode:11;
    unsigned int __unused4:5;
    unsigned int __data_offset;
    unsigned short int __data_selector;
    unsigned short int __unused5;
#ifdef __FC_MACHDEP_X86_64 /* only for x86_64 */
    unsigned int __mxcsr;
#endif
  }
fenv_t;

// From POSIX 1-2017:
// - "fexcept_t does not have to be an integer type."
// - "... the user cannot inspect it."
// Non-portable code may consider fexcept_t as a scalar; this allows
// such code to be parsed.
typedef unsigned int fexcept_t;

__FC_EXTERN volatile fenv_t __fc_fenv_state;

/*@
  assigns __fc_fenv_state \from indirect:excepts, __fc_fenv_state;
  assigns \result \from indirect:__fc_fenv_state, indirect:excepts;
*/
extern int feclearexcept(int excepts);

/*@
  assigns *envp \from __fc_fenv_state;
  assigns \result \from indirect:__fc_fenv_state;
*/
extern int fegetenv(fenv_t *envp);

/*@
  assigns *flagp \from __fc_fenv_state, excepts;
  assigns \result \from indirect:__fc_fenv_state, indirect:excepts;
*/
extern int fegetexceptflag(fexcept_t *flagp, int excepts);

/*@ assigns \result \from __fc_fenv_state; */
extern int fegetround(void);

/*@
  assigns *envp, __fc_fenv_state \from __fc_fenv_state;
  assigns \result \from indirect:__fc_fenv_state;
*/
extern int feholdexcept(fenv_t *envp);

/*@ assigns \result \from indirect:__fc_fenv_state, indirect:excepts; */
extern int feraiseexcept(int excepts);

/*@
  assigns __fc_fenv_state \from *envp;
  assigns \result \from indirect:__fc_fenv_state, indirect:*envp;
*/
extern int fesetenv(const fenv_t *envp);

/*@
  assigns __fc_fenv_state \from *flagp, excepts;
  assigns \result \from indirect:__fc_fenv_state, indirect:*flagp,
                        indirect:excepts;
*/
extern int fesetexceptflag(const fexcept_t *flagp, int excepts);

/*@
  assigns __fc_fenv_state \from indirect:__fc_fenv_state, indirect:round;
  assigns \result \from indirect:__fc_fenv_state, indirect:round;
*/
extern int fesetround(int round);

/*@ assigns \result \from indirect:excepts, __fc_fenv_state; */
extern int fetestexcept(int excepts);

/*@
  assigns __fc_fenv_state \from __fc_fenv_state, *envp;
  assigns \result \from indirect:__fc_fenv_state, indirect:*envp;
*/
extern int feupdateenv(const fenv_t *envp);


__END_DECLS

__POP_FC_STDLIB
#endif /* __FC_FENV */
