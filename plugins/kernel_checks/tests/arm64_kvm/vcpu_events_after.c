/* run.config
   OPT: -eva -eva-slevel 20 -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

/* Fixed control: validate the complete SError request before committing SEA. */

typedef unsigned long long u64;

#define EINVAL 22
#define ESR_ELX_ISS_MASK ((1ULL << 25) - 1)

struct kvm_vcpu {
  u64 pc;
  u64 pstate;
  u64 esr;
  int pending_exception;
  int abort_committed;
};

struct kvm_vcpu_events {
  int serror_pending;
  int serror_has_esr;
  int ext_dabt_pending;
  u64 serror_esr;
};

static int kvm_inject_sea_dabt(struct kvm_vcpu *vcpu)
{
  vcpu->esr = 0x96000010ULL;
  vcpu->pending_exception = 1;
  return 1;
}

static void commit_pending_events(struct kvm_vcpu *vcpu)
{
  if (!vcpu->pending_exception)
    return;

  vcpu->pc = 0x200;
  vcpu->pstate = 0x3c5;
  vcpu->pending_exception = 0;
  vcpu->abort_committed = 1;
}

static int set_events_after(struct kvm_vcpu *vcpu,
                            const struct kvm_vcpu_events *events)
{
  int ret = 0;

  if (events->serror_pending && events->serror_has_esr &&
      (events->serror_esr & ~ESR_ELX_ISS_MASK))
    return -EINVAL;

  if (events->ext_dabt_pending) {
    ret = kvm_inject_sea_dabt(vcpu);
    commit_pending_events(vcpu);
  }

  if (ret < 0)
    return ret;

  if (!events->serror_pending)
    return 0;

  return 0;
}

int main(void)
{
  struct kvm_vcpu vcpu = {
    .pc = 0x100,
    .pstate = 0,
  };
  const struct kvm_vcpu_events events = {
    .serror_pending = 1,
    .serror_has_esr = 1,
    .ext_dabt_pending = 1,
    .serror_esr = 1ULL << 32,
  };
  const u64 original_pc = vcpu.pc;
  const u64 original_pstate = vcpu.pstate;
  int ret = set_events_after(&vcpu, &events);

  /*@ assert rejected: ret == -EINVAL; */
  /*@ assert rejected_input_is_atomic:
        ret != -EINVAL ||
        (vcpu.pc == original_pc &&
         vcpu.pstate == original_pstate &&
         vcpu.abort_committed == 0); */
  return ret;
}
