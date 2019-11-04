/* run.config
DONTRUN: auxiliary file use by tests
*/
#include "signalled.h"

static sigjmp_buf jmp_ctxt;
static int got_signal;
static int testno = 0;

sigjmp_buf* get_jmp_ctxt(void) { return &jmp_ctxt; }

void signalled(int sig) {
  printf("signalled\n");
  struct sigaction sig_dfl;
  sig_dfl.sa_handler = SIG_DFL;
  sigemptyset(&sig_dfl.sa_mask);
  sigaction(SIGABRT,&sig_dfl,NULL);
  got_signal = 1;
  siglongjmp(jmp_ctxt,EXE_SIGNAL);
}

void signal_eval(int signalled, int expect_signal, const char* at) {
  printf("TEST %d: ", ++testno);
  if (signalled && expect_signal)
    printf("OK: Expected signal at %s\n", at);
  else if (!signalled && !expect_signal)
    printf("OK: Expected execution at %s\n", at);
  else if (!signalled && expect_signal) {
    printf("FAIL: Unexpected execution at %s\n", at);
    exit(1);
  } else if (signalled && !expect_signal) {
    printf("FAIL: Unexpected signal at %s\n", at);
    exit(2);
  }
}

void set_handler(void) {
  struct sigaction check_signal;
  check_signal.sa_handler = signalled;
  sigemptyset(&check_signal.sa_mask);
  check_signal.sa_flags = 0;
  sigaction(SIGABRT,&check_signal,NULL);
}

void test_successful(void) {
  struct sigaction sig_dfl;
  sig_dfl.sa_handler = SIG_DFL;
  sigemptyset(&sig_dfl.sa_mask);
  sigaction(SIGABRT,&sig_dfl,NULL);
  siglongjmp(jmp_ctxt,EXE_SUCCESS);
}
