/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) 2026 Frama-C Linux contributors                         */
/*                                                                        */
/**************************************************************************/

/*
 * Include the complete current ARM64 KVM guest translation unit under its
 * exact Kbuild command.  Keep __kvm_arm_vcpu_set_events() unmodified and
 * model only the cross-translation-unit exception injection and HYP commit
 * needed to expose its rejected-request state transition.
 */
#include <linux/kvm_host.h>

#include <asm/kvm_emulate.h>

static int frama_c_abort_committed;

int kvm_inject_sea(struct kvm_vcpu *vcpu, bool iabt, u64 addr)
{
  (void)iabt;
  (void)addr;
  vcpu->arch.iflags |= unpack_vcpu_flag(PENDING_EXCEPTION);
  return 1;
}

void __kvm_adjust_pc(struct kvm_vcpu *vcpu)
{
  if (vcpu->arch.iflags & unpack_vcpu_flag(PENDING_EXCEPTION)) {
    *vcpu_pc(vcpu) = 0x200;
    *vcpu_cpsr(vcpu) = 0x3c5;
    vcpu->arch.iflags &= ~unpack_vcpu_flag(PENDING_EXCEPTION);
    frama_c_abort_committed = 1;
  }
}

/* Select the invalid-ESR check, not the unsupported-RAS check. */
#define cpus_have_final_cap(capability) true

/* The modeled injection ignores the fault address. */
#define kvm_vcpu_get_hfar(vcpu) 0ULL

/* Execute the modeled HYP boundary directly in this bounded scenario. */
#undef kvm_call_hyp
#define kvm_call_hyp(function, ...) function(__VA_ARGS__)

#include <guest.c>

int frama_c_arm64_kvm_vcpu_events(void)
{
  struct kvm_vcpu vcpu;
  struct kvm_vcpu_events events = { 0 };
  unsigned long original_pc;
  unsigned long original_pstate;
  int ret;

  vcpu.arch.iflags = 0;
  vcpu.arch.ctxt.regs.pc = 0x100;
  vcpu.arch.ctxt.regs.pstate = 0;
  vcpu.mmio_needed = true;
  frama_c_abort_committed = 0;

  events.exception.serror_pending = true;
  events.exception.serror_has_esr = true;
  events.exception.ext_dabt_pending = true;
  events.exception.serror_esr = BIT_ULL(63);

  original_pc = *vcpu_pc(&vcpu);
  original_pstate = *vcpu_cpsr(&vcpu);
  ret = __kvm_arm_vcpu_set_events(&vcpu, &events);

  /*@ assert rejected: ret == -EINVAL; */
  /*@ assert rejected_input_is_atomic:
        ret != -EINVAL ||
        (vcpu.arch.ctxt.regs.pc == original_pc &&
         vcpu.arch.ctxt.regs.pstate == original_pstate &&
         frama_c_abort_committed == 0); */
  return ret;
}
