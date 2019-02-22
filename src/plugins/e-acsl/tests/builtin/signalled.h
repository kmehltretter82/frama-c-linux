#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <setjmp.h>

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define AT __FILE__ ":" TOSTRING(__LINE__)

#define EXE_SUCCESS 1
#define EXE_SIGNAL 2

void signal_eval(int signalled, int expect_signal, const char *at);

void signalled(int sig);

sigjmp_buf* get_jmp_ctxt(void);

void set_handler(void);

void test_successful(void);

/* The following macro runs a chunk of code in a subprocess and evaluates
   the result. This macro assumes that fork is always successful. */
#define SIGNALLED_AT(code, expect_signal, at) {                         \
    sigjmp_buf* jmp_ctxt = get_jmp_ctxt();                                 \
    switch (sigsetjmp(*jmp_ctxt,1)) {                                   \
      case 0: {                                                         \
        set_handler();                                                  \
        code;                                                           \
        test_successful();                                              \
        break;                                                          \
      }                                                                 \
      case EXE_SUCCESS: {                                               \
        signal_eval(0,expect_signal,at);                                \
        break;                                                          \
      }                                                                 \
      case EXE_SIGNAL: {                                                \
        signal_eval(1,expect_signal,at);                                \
        break;                                                          \
      }                                                                 \
      default: {                                                        \
        printf("FAIL: Unexpected value return from test at %s\n", at);  \
        exit(3);                                                        \
      }                                                                 \
    }                                                                   \
  }

#define ABRT(code) SIGNALLED_AT(code, 1, AT)
#define OK(code) SIGNALLED_AT(code, 0, AT);
#define ABRT_AT(code,at) SIGNALLED_AT(code, 1, at)
#define OK_AT(code,at) SIGNALLED_AT(code, 0, at)
