/* run.config
   OPT: -kernel-checks -kernel-checks-ast-only -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

typedef unsigned long gpa_t;

#define INVALID_GPA (~(gpa_t)0)

struct kvm;

int kvm_write_guest(struct kvm *kvm, gpa_t gpa,
                    const void *data, unsigned long len);
int kvm_write_guest_lock(struct kvm *kvm, gpa_t gpa,
                         const void *data, unsigned long len);

gpa_t ignored_result_returns_address(struct kvm *kvm, gpa_t base,
                                     const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base, data, len);
  return base;
}

int ignored_result_returns_zero(struct kvm *kvm, gpa_t base,
                                const void *data, unsigned long len)
{
  kvm_write_guest(kvm, base, data, len);
  return 0;
}

void ignored_void_best_effort(struct kvm *kvm, gpa_t base,
                              const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base, data, len);
}

gpa_t checked_result(struct kvm *kvm, gpa_t base,
                     const void *data, unsigned long len)
{
  if (kvm_write_guest_lock(kvm, base, data, len))
    return INVALID_GPA;

  return base;
}

gpa_t ignored_only_on_error_path(struct kvm *kvm, gpa_t base,
                                 const void *data, unsigned long len,
                                 int fail)
{
  if (fail) {
    kvm_write_guest_lock(kvm, base, data, len);
    return INVALID_GPA;
  }

  return base;
}

int ignored_with_unrelated_status(struct kvm *kvm, gpa_t base,
                                  const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base, data, len);
  return 7;
}

gpa_t composite_address_component_is_not_the_written_address(
  struct kvm *kvm, gpa_t base, gpa_t offset,
  const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base + offset, data, len);
  return offset;
}

gpa_t arithmetic_address_return_is_not_the_written_address(
  struct kvm *kvm, gpa_t base, const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base, data, len);
  return base + 64;
}

int zero_variable_in_nonzero_expression_is_not_success(
  struct kvm *kvm, gpa_t base, const void *data, unsigned long len)
{
  int status;

  kvm_write_guest_lock(kvm, base, data, len);
  status = 0;
  return status + 7;
}

void *pointer_null_is_not_assumed_to_be_success(
  struct kvm *kvm, gpa_t base, const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base, data, len);
  return (void *)0;
}

_Bool boolean_false_is_not_assumed_to_be_success(
  struct kvm *kvm, gpa_t base, const void *data, unsigned long len)
{
  kvm_write_guest_lock(kvm, base, data, len);
  return 0;
}
