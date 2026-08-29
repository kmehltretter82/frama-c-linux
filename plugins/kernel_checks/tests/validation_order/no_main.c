/* run.config
   OPT: -kernel-checks -kernel-checks-ast-only -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

#define EINVAL 22

struct state {
  int committed;
};

struct request {
  int commit;
  int invalid;
};

static void commit_state(struct state *state)
{
  state->committed = 1;
}

int ioctl_without_program_entry(struct state *state,
                                const struct request *request)
{
  int invalid = request->invalid;

  if (request->commit)
    commit_state(state);

  if (invalid)
    return -EINVAL;

  return 0;
}
