/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) 2026 Frama-C Linux contributors                         */
/*                                                                        */
/**************************************************************************/

/*
 * Include the complete current ARM64 KVM guest translation unit.  The
 * kernel-checks MTE protocol analysis inspects every defined function; Eva
 * starts from the bounded entry below and need not synthesize a struct kvm.
 */
#include <guest.c>

int frama_c_arm64_kvm_mte_scan(void)
{
  return 0;
}
