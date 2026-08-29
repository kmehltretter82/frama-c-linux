/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

#define EINVAL 22
#define EIO 5

struct state {
  int committed;
};

struct request {
  int invalid;
};

static int cleanup_error_is_not_input_validation(struct state *state,
                                                 const struct request *request,
                                                 int helper_error)
{
  (void)request;
  state->committed = 1;
  if (helper_error)
    return -EINVAL;
  return 0;
}

static int different_errno_is_out_of_scope(struct state *state,
                                           const struct request *request)
{
  state->committed = 1;
  if (request->invalid)
    return -EIO;
  return 0;
}

static int indirect_rejection_is_out_of_scope(struct state *state,
                                              const struct request *request)
{
  int ret = 0;

  state->committed = 1;
  if (request->invalid)
    ret = -EINVAL;
  return ret;
}

int main(void)
{
  struct state state = { 0 };
  const struct request request = { 0 };

  return cleanup_error_is_not_input_validation(&state, &request, 0)
       + different_errno_is_out_of_scope(&state, &request)
       + indirect_rejection_is_out_of_scope(&state, &request);
}
