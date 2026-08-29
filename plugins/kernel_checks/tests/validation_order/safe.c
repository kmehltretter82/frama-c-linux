/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

#define EINVAL 22

struct state {
  int committed;
  int invalid;
};

struct request {
  int commit;
  int invalid;
};

static void inspect_request(const struct request *request)
{
  (void)request;
}

/* Deliberately lacks const: the interprocedural summary must still prove that
   this helper only observes the state. */
static int inspect_state(struct state *state)
{
  return state->committed;
}

/* KVM uses this fail-stop effect for internal invariant failures. */
static void kvm_vm_bugged(struct state *state)
{
  state->committed = 1;
}

static int validate_first(struct state *state,
                          const struct request *request)
{
  if (request->invalid)
    return -EINVAL;

  state->committed = request->commit;
  return 0;
}

static int const_helper_is_not_mutation(struct state *state,
                                        const struct request *request)
{
  inspect_request(request);
  (void)inspect_state(state);
  if (request->invalid)
    return -EINVAL;

  state->committed = 1;
  return 0;
}

static int same_object_is_not_two_roles(struct state *state)
{
  state->committed = 1;
  if (state->invalid)
    return -EINVAL;
  return 0;
}

static int fail_stop_is_not_transaction_state(struct state *state,
                                              const struct request *request)
{
  kvm_vm_bugged(state);
  if (request->invalid)
    return -EINVAL;
  return 0;
}

int main(void)
{
  struct state state = { 0 };
  const struct request request = { 0 };

  return validate_first(&state, &request)
       + const_helper_is_not_mutation(&state, &request)
       + same_object_is_not_two_roles(&state)
       + fail_stop_is_not_transaction_state(&state, &request);
}
