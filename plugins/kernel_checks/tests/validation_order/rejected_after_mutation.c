/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_arm64
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

static int rejected_after_call(struct state *state,
                               const struct request *request)
{
  int invalid = request->invalid;

  if (request->commit)
    commit_state(state);

  if (invalid)
    return -EINVAL;

  return 0;
}

static int rejected_after_write(struct state *state,
                                const struct request *request)
{
  int invalid = request->invalid;

  state->committed = 1;
  if (invalid)
    return -EINVAL;

  return 0;
}

int main(void)
{
  struct state state = { 0 };
  const struct request request = { 0 };

  return rejected_after_call(&state, &request)
       + rejected_after_write(&state, &request);
}
