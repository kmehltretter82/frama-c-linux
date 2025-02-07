/* run.config


   STDOPT: #"-eva-slevel 2"

*/
/*


*/
#include <errno.h>
#include <signal.h>
#ifdef WITH_SIGNAL_C
  #include <signal.c>
#endif

volatile int nondet;


int test_sigaction() {
  sigset_t s;
  if (sigemptyset(&s)) return 1;
  if (sigaddset(&s, SIGALRM)) {
    return -1;
  }
  if (sigdelset(&s, SIGUSR1)) {
    return -1;
  }
  if (!sigismember(&s, SIGALRM)) return 2;
  sigfillset(&s);
  if (!sigismember(&s, SIGPIPE)) return 3;
  sigset_t uninit;
  if (nondet) {
    if (sigaddset(&uninit, SIGKILL)) {
      return -1;
    }
    //@ assert unreachable_if_precise: \false;
  }

  sigset_t old;
  if (sigprocmask(SIG_SETMASK, 0, &old)) {
    return -1;
  }
  if (sigaddset(&old, SIGALRM)) {
    return -1;
  }
  if (sigprocmask(SIG_SETMASK, &old, 0)) {
    return -1;
  }
  if (sigprocmask(SIG_BLOCK, &s, &old)) {
    return -1;
  }

  int kill_res = kill(42, SIGTERM);

  struct sigaction sa1, sa2;
  if (sigaction(SIGCHLD, 0, &sa1)) {
    return -1;
  }
  if (sigaction(SIGCONT, &sa1, &sa2)) {
    return -1;
  }
  if (sigaction(SIGUSR1, &sa2, 0)) {
    return -1;
  }

  //@ assert valid_nsig: NSIG >= 0;

  if (nondet) {
    errno = 0;
    int r = sigsuspend(&s);
    //@ assert sigsuspend_errno_eintr: errno == EINTR;
    //@ assert sigsuspend_return: r == -1;
  }

  return 0;
}

























int main() {
  test_sigaction();

  return 0;
}
