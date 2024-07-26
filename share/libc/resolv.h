/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2025                                               */
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

#ifndef __FC_RESOLV_H
#define __FC_RESOLV_H
#include "features.h"
__PUSH_FC_STDLIB

__BEGIN_DECLS

// Note: resolv.h is neither ISO-C nor POSIX

// Note: the __res_state struct is opaque in <resolv.h>, but to minimize issues
// with initialization of incomplete structures (e.g. when using -lib-entry),
// we fill it in with a generic field (the size is the one indicated in
// <bits/types/res_state.h>). If necessary for a case study, consider importing
// the full struct definition here.
struct __res_state {
  char __glibc_specific_fields[512];
};

typedef struct __res_state *res_state;

volatile struct __res_state __fc_resolv; // internal state;

// deprecated
/*@
  assigns \result \from indirect:__fc_resolv;
  assigns __fc_resolv \from __fc_resolv;
*/
extern int res_init(void);

/*@
  assigns *statep \from *statep;
  assigns \result \from indirect:*statep;
*/
extern int res_ninit(res_state statep);

/*@
  assigns \result, *statep, answer[0 .. anslen - 1] \from *statep,
    indirect:dname[0..], indirect:class, indirect:type, indirect:anslen;
*/
extern int res_nquery(res_state statep,
                      const char *dname, int class, int type,
                      unsigned char *answer, int anslen);

/*@
  assigns \result, *statep, answer[0 .. anslen - 1] \from *statep,
    indirect:dname[0..], indirect:class, indirect:type, indirect:anslen;
*/
extern int res_nsearch(res_state statep,
                       const char *dname, int class, int type,
                       unsigned char *answer, int anslen);

/*@
  assigns \result, *statep, answer[0 .. anslen - 1] \from *statep,
    indirect:name[0..], indirect:domain[0..], indirect:class, indirect:type,
    indirect:anslen;
*/
extern int res_nquerydomain(res_state statep,
                            const char *name, const char *domain,
                            int class, int type, unsigned char *answer,
                            int anslen);

/*@
  assigns \result, *statep, buf[0 .. buflen - 1] \from *statep,
    indirect:op, indirect:dname[0..], indirect:class, indirect:datalen,
    indirect:newrr[0..], indirect:buflen;
*/
extern int res_nmkquery(res_state statep,
                        int op, const char *dname, int class,
                        int type, const unsigned char *data, int datalen,
                        const unsigned char *newrr,
                        unsigned char *buf, int buflen);

/*@
  assigns \result, *statep, answer[0 .. anslen - 1] \from *statep,
    msg[0 .. msglen - 1], indirect:anslen;
*/
extern int res_nsend(res_state statep,
                     const unsigned char *msg, int msglen,
                     unsigned char *answer, int anslen);

/*@
  //missing: assigns \from 'resolver'
  assigns \result \from indirect:exp_dn[0..], indirect:dnptrs[0..][0..],
                        indirect:comp_dn[0..];
  assigns comp_dn[0 .. length-1] \from exp_dn[0..], dnptrs[0..][0..],
                                       indirect:(*lastdnptr)[0..];
*/
extern int dn_comp(const char *exp_dn, unsigned char *comp_dn,
                   int length, unsigned char **dnptrs,
                   unsigned char **lastdnptr);

/*@
  //missing: assigns \from 'resolver'
  assigns \result \from indirect:msg[0..], indirect:eomorig[0..],
                        indirect:comp_dn[0..];
  assigns exp_dn[0 .. length-1] \from msg[0..], eomorig[0..], comp_dn[0..];
*/
extern int dn_expand(const unsigned char *msg,
                     const unsigned char *eomorig,
                     const unsigned char *comp_dn, char *exp_dn,
                     int length);

__END_DECLS

__POP_FC_STDLIB
#endif
