/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) 2026 Frama-C Linux contributors                         */
/*                                                                        */
/**************************************************************************/

/*
 * Include the complete current generic KVM IRQ-routing translation unit
 * with its exact ARM64 Kbuild command.  SRCU lifetime is outside this
 * bounded scenario; expose the already-published routing pointer to Eva.
 */
#include <linux/kvm_host.h>

#undef srcu_dereference_check
#define srcu_dereference_check(pointer, srcu, condition) (pointer)

#include <irqchip.c>

union frama_c_irq_routing_storage {
  struct kvm_irq_routing_table table;
  unsigned char bytes[sizeof(struct kvm_irq_routing_table) +
                      sizeof(struct hlist_head)];
};

static struct kvm frama_c_kvm;
static union frama_c_irq_routing_storage frama_c_routing;
static struct kvm_kernel_irq_routing_entry
  frama_c_entries[KVM_NR_IRQCHIPS];

static void frama_c_prepare_irq_routing(void)
{
  frama_c_routing.table.nr_rt_entries = 1;
  frama_c_kvm.irq_routing = &frama_c_routing.table;
}

/*
 * The u32 count makes the source comparison unsigned.  UINT_MAX arriving
 * through struct kvm_irqfd therefore becomes UINT_MAX again at the guard and
 * cannot reach map[-1].  This is a real-source, zero-finding control.
 */
int frama_c_arm64_kvm_irqfd_gsi(void)
{
  frama_c_prepare_irq_routing();
  return kvm_irq_map_gsi(&frama_c_kvm, frama_c_entries, (int)~0U);
}

/*
 * Deliberately bypass the real guard to prove that the checker recognizes
 * the counted KVM field in this full translation unit.  This function is a
 * sensitivity control, not Linux source and not a kernel bug claim.
 */
int frama_c_arm64_kvm_irq_routing_negative_control(void)
{
  frama_c_prepare_irq_routing();
  return frama_c_routing.table.map[-1].first != 0;
}
