/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) 2026 Frama-C Linux contributors                         */
/*                                                                        */
/**************************************************************************/

/*
 * Bounded replay of Linux commit a25bc8486f9c0.  The mapped compilation
 * database supplies the exact ARM64 KVM hypercalls.c command.  Include its
 * headers first, then replace only copy_from_user() with an extent contract
 * before including the complete current translation unit.
 */
#include <linux/arm-smccc.h>
#include <linux/kvm_host.h>

#include <asm/kvm_emulate.h>

#include <kvm/arm_hypercalls.h>
#include <kvm/arm_psci.h>

/*@
  requires destination_extent:
    bytes == 0 || \valid(((unsigned char *)to) + (0 .. bytes - 1));
  requires source_extent:
    bytes == 0 || \valid_read(((const unsigned char *)from) +
                              (0 .. bytes - 1));
  assigns \result,
          ((unsigned char *)to)[0 .. bytes - 1]
    \from bytes, ((const unsigned char *)from)[0 .. bytes - 1];
  ensures copy_succeeds: \result == 0;
 */
unsigned long frama_c_copy_from_user(void *to, const void *from,
                                     unsigned long bytes);

#undef copy_from_user
#define copy_from_user(to, from, bytes) \
  frama_c_copy_from_user((to), (from), (bytes))

#include <hypercalls.c>

static unsigned char frama_c_fw_reg_user_value[16];

static struct kvm_one_reg frama_c_oversized_fw_reg(void)
{
  struct kvm_one_reg reg = {
    .id = (KVM_REG_ARM_PSCI_VERSION & ~KVM_REG_SIZE_MASK) |
          KVM_REG_SIZE_U128,
    .addr = (u64)(unsigned long)frama_c_fw_reg_user_value,
  };

  return reg;
}

/* The actual fixed function from the included current translation unit. */
int frama_c_arm64_kvm_fw_reg_fixed(void)
{
  struct kvm_one_reg reg = frama_c_oversized_fw_reg();

  return kvm_arm_set_fw_reg((struct kvm_vcpu *)0, &reg);
}

/*
 * Exact vulnerable prefix from a25bc8486f9c0^, reduced after the copy.  The
 * oversized synthetic ID cannot match any firmware-register switch case, so
 * the omitted suffix only returns -ENOENT and cannot affect the overflow.
 */
int frama_c_arm64_kvm_fw_reg_before(void)
{
  struct kvm_one_reg reg = frama_c_oversized_fw_reg();
  void __user *uaddr = (void __user *)(long)reg.addr;
  u64 val;

  if (copy_from_user(&val, uaddr, KVM_REG_SIZE(reg.id)))
    return -EFAULT;

  return -ENOENT;
}
