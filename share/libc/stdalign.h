/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

// Non-ISO, Non-POSIX; header provided only for improved compatibility with
// non-portable code.

#ifndef __FC_STDALIGN_H
#define __FC_STDALIGN_H
#include "features.h"
__PUSH_FC_STDLIB
__BEGIN_DECLS

#define alignas _Alignas
#define alignof _Alignof

__END_DECLS
__POP_FC_STDLIB
#endif
