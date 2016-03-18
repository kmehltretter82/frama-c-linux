/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2015                                               */
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
/*  for more details (enclosed in the file license/LGPLv2.1).             */
/*                                                                        */
/**************************************************************************/

#ifndef E_ACSL_ASSERT
#define E_ACSL_ASSERT

#include "e_acsl_string.h"
#include "e_acsl_printf.h"

/* Drop-in replacement for abort function */
#define abort() exec_abort(__LINE__, __FILE__)

/* Output a message to error stream using printf-like format string and abort
 * the execution. This is a wrapper for eprintf combined with abort */
static void vabort(char *fmt, ...);

/* Drop-in replacement for system-wide assert macro */
#define assert(expr) \
  ((expr) ? (void)(0) : vabort("%s at %s:%d\n", \
    #expr, __FILE__,__LINE__))

/* Assert with printf-like error message support */
#define vassert(expr, fmt, ...) \
    vassert_fail(expr, __LINE__, __FILE__, fmt, __VA_ARGS__)

static void exec_abort(int line, const char *file) {
  eprintf("Execution aborted (%s:%d)\n", file, line);
  exit(1);
}

static void vassert_fail(int expr, int line, char *file, char *fmt,  ...) {
  if (!expr) {
    char *afmt = "%s at %s:%d\n";
    char buf [strlen(fmt) + strlen(afmt) + PATH_MAX +  11];
    sprintf(buf, afmt, fmt, file, line);
    fmt = buf;

    va_list va;
    va_start(va,fmt);
    _format(NULL,_charc_stderr,fmt,va);
    va_end(va);
    abort();
  }
}

/* Print a message to stderr and abort the execution */
static void vabort(char *fmt, ...) {
  va_list va;
  va_start(va,fmt);
  _format(NULL,_charc_stderr,fmt,va);
  va_end(va);
  abort();
}

/* Default implementation of E-ACSL runtime assertions */
static void runtime_assert(int predicate, char *kind,
  char *fct, char *pred_txt, int line) {
  if (!predicate) {
    eprintf("%s failed at line %d in function %s.\n"
      "The failing predicate is:\n%s.\n", kind, line, fct, pred_txt);
    exit(1);
  }
}

/* Alias for runtime assertions. Since `__e_acsl_assert` is added as a weak
 * alias user-defined implementation of the `__e_acsl_assert` function will be
 * preferred at link time. */
void __e_acsl_assert(int pred, char *kind, char *fct, char *pred_txt, int line)
  __attribute__ ((weak, alias ("runtime_assert")));

/* Instances of assertions shared accross different memory models */

/* Abort the execution if the size of the pointer computed during
 * instrumentation (_ptr_sz) does not match the size of the pointer used
 * by a compiler (void*) */
#define arch_assert(_ptr_sz) \
  vassert(_ptr_sz == sizeof(void*), \
    "Mismatch of instrumentation- and compile-time pointer sizes: " \
    "%lu vs %lu\n", _ptr_sz, sizeof(void*))

#endif
