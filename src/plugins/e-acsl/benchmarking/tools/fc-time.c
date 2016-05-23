/* Copyright (C) 1990, 91, 92, 93, 96 Free Software Foundation, Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA. */

/* fc-time -- mesaure real time of an executed command */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <stdarg.h>
#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/resource.h>

/* Extra declarations to suppress warnings in -std=c99 or -std=c11 modes */
int kill(pid_t pid, int sig);

const char *strdup(const char *s);

pid_t wait4(pid_t pid, int *status, int options, struct rusage *rusage);

typedef void (*sighandler_t) (int);

#ifdef __linux__
#include <linux/limits.h>
#endif

/* Minimal reported runtime */
#define MINTIME  0.001

/* Minimal time limit after which a program is forcibly terminated  */
#define MINLIMIT 0.1

/* Name of the output file. Only used if -o option is given.  */
static const char *outfile;

/* Output stream, defaults to stderr */
static FILE *outfp;

/* If true, append to `outfile' rather than truncating it  */
static int append;

/* Program name */
static const char * program_name = NULL;

/* Time limit in seconds */
long double time_limit = 0;

/* Verbosity level */
int verbose;

/* Gather memory stats via /proc/[pid]/statm */
int memory;

/* Struct for holding the results of memory statistics */
struct statistics {
  unsigned long vsize;      /* (1) total program size (page size) */
  unsigned long rss;        /* (2) resident set size (page size) */
  unsigned long share;      /* (3) shared pages (page size) */
  unsigned long text;       /* (4) text (page size) */
  unsigned long lib;        /* (5) library (page size) */
  unsigned long data;       /* (6) data + stack (page size) */

  /* The number of times a procfile has been read */
  unsigned long count;
  int status; /* exit status */

  struct timeval start; /* timestamp of program start */
  struct timeval finish; /* timestamp of program end */
  struct rusage resusage; /* struct for use with getrusage */
};

/* Name of the used memory stat file */
char procfile [PATH_MAX];

/* Memory stat file stream */
FILE *procfp = NULL;

/* Default report format string */
char *report_format = "%e\n";

/* Memory size units */
#define B_SZ  1
#define KB_SZ 1024
#define MB_SZ (1024*KB_SZ)
#define GB_SZ (1024*MB_SZ)

/* Reported block unit */
static int block_size;

/* Short options */
static const char *shortopts = "+ao:l:vmB:f:";

/* Long options */
static struct option longopts[] = {
  {"limit", required_argument, NULL, 'l'},
  {"verbose", no_argument, NULL, 'v'},
  {"append", no_argument, NULL, 'a'},
  {"help", no_argument, NULL, 'h'},
  {"output-file", required_argument, NULL, 'o'},
  {"memory", required_argument, NULL, 'm'},
  {"block-bize", required_argument, NULL, 'B'},
  {"format", required_argument, NULL, 'f'},
  {NULL, no_argument, NULL, 0}
};

/* Print help page and exit */
static void usage (FILE *stream, int status) {
  fprintf(stream,
"NAME:\n"
"  fc-time -- measure execution time and/or memory consumption of a command\n"
"SYNOPSIS:\n"
"  fc-time [options] command [arg...]\n"
"OPTIONS:\n"
"  -h, --help     print this help page and exit.\n"
"  -o FILE        send output to a named file [stderr].\n"
"  -a, --append   append an output file without truncating it (with -o).\n"
"  -l SECONDS     limit in seconds arter which a program is terminated\n"
" even if it is not finshed. The limit needs to be specified with seconds\n"
" precision.\n"
"  -m, --memory - collect memory statistics [disabled].\n"
"  -v             warn if a program has been terminated via -l option.\n"
"  -f             printf-like report format string.\n"
"     %%e - elapsed real time [seconds:milliseconds].\n"
"     %%E - same as %%e\n"
"     %%U - total time spent in user mode [seconds:milliseconds].\n"
"     %%S - total time spent in kernel mode [seconds:milliseconds].\n"
"     %%v - virtual memory consumption peak [bytes].\n"
"     %%t - text segment size [bytes].\n"
"     %%d - data + stack segments sizes [bytes].\n"
"     %%r - maximum resident set size [bytes].\n"
" Memory-related measurements (e.g., virtual memory consumption or rss)\n"
" are disabled by default. Unless -m option is used they are reported as\n"
" zeroes. Computing memory peaks may result in the increase of runtime.\n"
"  -B, --byte-size=<B|KB|MB|GB> - change reported memory unit [B].\n");
  exit(status);
}

/* Error reporting function. Replica of the GNU error (3).
 * Added for portability purposes. */
static void error(int status, int errnum, const char *format, ...) {
  fflush(stderr); /* Flush streams */
  fflush(stdout);

  if (program_name) /* Report program name */
    fprintf(stderr, "%s: ", program_name);

  va_list va; /* Pass the error message given by the user */
  va_start(va, format);
  vfprintf(stderr, format, va);
  va_end(va);

  if (errnum) /* Report error given via errno */
    fprintf(stderr, ": %s", strerror(errnum));

  /* Add the newline at the end */
  fprintf(stderr, "\n");

  /* Exit if status is a non-zero */
  if (status)
    exit(status);
}

#define warning(_fmt, ...) \
  if (verbose) {  \
    error(0, 0, _fmt, __VA_ARGS__); \
  }

/* Initialize the options and parse the command line arguments.
   Also note the position in ARGV where the command to time starts. */
static const char ** getargs (int argc, char **argv) {
  int optc;
  outfile = NULL;
  outfp   = stderr; /* Output to  stderr by default */
  append  = 0;
  verbose = 0;
  memory  = 0;
  block_size = KB_SZ;

  while ((optc = getopt_long(argc, argv, shortopts, longopts, NULL)) != EOF) {
    switch (optc) {
      case 'a':
        append = 1;
        break;
      case 'h':
        usage (stdout, 0);
      case 'o':
        outfile = optarg;
        break;
      case 'v':
        verbose = 1;
        break;
      case 'm':
        memory = 1;
        break;
      case 'f':
        report_format = (char*)strdup(optarg);
        break;
      case 'l':
        /* Convert time limit to seconds */
        time_limit = strtold(optarg, NULL);

        /* Abort if the time limit provided at input is invalid or less than
           the threshold given by MINLIMIT */
        if (time_limit < MINLIMIT)
          error(1, errno, "Bad time limit specification: '%s'."
            " Expected positive number greater than %0.3f", optarg, MINLIMIT);
        /* Detect over- or underflow */
        if (errno == ERANGE)
          error(1, errno, "%s", optarg);
        break;
	    case 'B': { /* reported unit size */
        switch(optarg[0]) {
          case 'B': /* report memory in bytes */
            block_size = B_SZ;
            break;
          case 'K': /* ... kilobytes */
            block_size = KB_SZ;
            break;
          case 'M': /* ... megabytes */
            block_size = MB_SZ;
            break;
          case 'G': /* ... gigabytes */
            block_size = GB_SZ;
            break;
          default:
            error(1, 0, "Bad block size specification (%s), expected B,K,M or G", optarg);
        }
        break;
      }
      default:
        usage (stderr, 1);
    }
  }

  if (optind == argc)
    usage (stderr, 1);

  if (outfile) {
    if (append)
      outfp = fopen (outfile, "a");
    else
      outfp = fopen (outfile, "w");
    if (outfp == NULL)
      error(1, errno, "%s", outfile);
  }
  return (const char **) &argv[optind];
}

/* Convert timeval into a double with millisecond precision */
#define TIMEWMS(_tval) (_tval.tv_sec + (_tval.tv_usec/1000000.0))
#define TIMEDIFF(_finish,_start) (TIMEWMS(_finish) - TIMEWMS(_start))

/* Assign the max of _old and _new to _old */
#define assignmax(_old, _new) _old = (_old > _new) ? _old : _new

/* Observe the child's execution, collect memory stats and terminate the
 * execution if the time limit is exceeded
 *
 * - This function is invoked only if either `time_limit' or `memory'
 *   are specified, i.e., a user requests either to collect memory stats
 *   or terminate the execution upon exceeding some time limit.
 *
 * - For the case when a time limit is given but memory statistics do not
 *   need to be collected the parent process checks if the time limit is
 *   exceeded each second. This is to limit the interference
 *
 * - If memory stats are collected, then checking time limit and reading
 *   procfile is done in a cycle without sleeping periods. This may slightly
 *   extend the execution of the program
*/
int observe(pid_t chpid, struct statistics * stats) {
  int status;
  pid_t rpid;

  while (!(rpid = wait4(chpid, &status, WNOHANG, &stats->resusage))) {
    gettimeofday(&stats->finish, NULL);
    if (time_limit && TIMEDIFF(stats->finish, stats->start) > time_limit) {
      warning("Warning: Attempting graceful termination due exceeded time "
          "limit of %0.2Lf seconds", "", time_limit);
      kill(chpid, SIGTERM);
      break;
    } else {
      /* No mem stats need to be collected, sleep for one second */
      if (!memory) {
        sleep(1);
      /* Mem stats need to be collected */
      } else {
        unsigned long vsize, rss, share, text, lib, data;
        /* Open and read process file */
        procfp = fopen(procfile, "r");
        if (!procfp)
          error(1, errno, "cannot open process memory stat file %s", procfile);
        fscanf(procfp, "%lu %lu %lu %lu %lu %lu",
          &vsize, &rss, &share, &text, &lib, &data);
        assignmax(stats->vsize, vsize);
        assignmax(stats->rss, rss);
        assignmax(stats->share, share);
        assignmax(stats->text, text);
        assignmax(stats->lib, lib);
        assignmax(stats->data, data);
        fclose(procfp);
        stats->count++;
      }
    }
  }

  if (rpid == -1)
    return 0;
  return 1;
}

/* Run command and return statistics on it. */
static int run_command (const char ** cmd) {
  pid_t pid = 0;			/* Pid of child  */
  int status = 0;     /* Status of a child */
  sighandler_t interrupt_signal, quit_signal;

  struct statistics stats;
  memset(&stats, 0, sizeof(struct statistics));

  /* Fork the child process */
  pid = fork();

  /* Copy the name of the stat file to the `procfile` global */
  sprintf(procfile, "/proc/%d/statm", pid);

  /* Start measuring real time */
  gettimeofday(&stats.start, NULL);

  if (pid < 0) {
    error(1, errno, "cannot fork");
  } else if (pid == 0) { /* If child. */
    execvp(cmd[0], (char *const*) cmd);
    error(0, errno, "cannot run %s", cmd[0]);
    exit(errno == ENOENT ? 127 : 126);
  }

  /* Have signals kill the child but not self */
  interrupt_signal = signal(SIGINT, SIG_IGN);
  quit_signal = signal(SIGQUIT, SIG_IGN);

  /* Time limit has been specified. Observe execution of the child process
   * and terminate the program after the time limit has been exceeded. */
  if (time_limit || memory) {
    if (observe(pid, &stats) == 0)
      error(1, errno, "error waiting for child process");
  /* No time limit given. Run the program as is and compute the runtime after
   * the process terminates. */
  } else {
    pid_t rpid = wait4(pid, &status, 0, &stats.resusage);
    gettimeofday(&stats.finish, NULL);
    if (rpid == -1)
      error (1, errno, "error waiting for child process");
  }

  /* Re-enable signals.  */
  signal(SIGINT, interrupt_signal);
  signal(SIGQUIT, quit_signal);

  /* Format string for report */
  char *fmt = report_format;

  /* Page size (/proc/[pid]/statm) reports sizes in pages */
  long pagesz = sysconf(_SC_PAGESIZE);

  while(*fmt != '\0') {
    switch(*fmt) {
      case '%': {
        fmt++;
	      switch (*fmt) {
          /* Elapsed time with millisecond precition */
          case 'E':
          case 'e': {
            double elapsed = TIMEWMS(stats.finish) - TIMEWMS(stats.start);
            fprintf(outfp, "%0.3f", (elapsed > MINTIME) ? elapsed : MINTIME);
            break;
          }
          /* Time spent in kernel mode */
          case 'S':
            fprintf(outfp, "%0.3f", TIMEWMS(stats.resusage.ru_stime));
            break;
          /* Time spent in user mode */
          case 'U':
            fprintf(outfp, "%0.3f", TIMEWMS(stats.resusage.ru_utime));
            break;
          case 'v':
            fprintf(outfp, "%lu", (stats.vsize*pagesz)/block_size);
            break;
          case 'd':
            fprintf(outfp, "%lu", (stats.data*pagesz)/block_size);
            break;
          case 't':
            fprintf(outfp, "%lu", (stats.text*pagesz)/block_size);
            break;
          case 'r':
            fprintf(outfp, "%lu", (stats.rss*pagesz)/block_size);
            break;
          default:
            fprintf(outfp, "???");
            break;
        }
        break;
      }
      case '\\': {
        fmt++;
	      switch (*fmt) {
	        case 't':
	          putc ('\t', outfp);
	          break;
	        case 'n':
	          putc ('\n', outfp);
	          break;
	        case '\\':
	          putc ('\\', outfp);
	          break;
	        default:
	          putc ('?', outfp);
	          putc ('\\', outfp);
	          putc (*fmt, outfp);
	      }
	      break;
      }
      default: {
        putc (*fmt, outfp);
      }
    }
    fmt++;
  }

  fflush(outfp);
  /* ... and return the status of the child */
  return status;
}

int main (int argc, char **argv) {
  program_name = *argv;
  const char **command_line = getargs(argc, argv);
  int status = run_command(command_line);

  /* Examining exit status of wait */
  if (WIFSTOPPED(status))
    exit(WSTOPSIG(status));
  else if (WIFSIGNALED(status))
    exit(WTERMSIG(status));
  else if (WIFEXITED(status))
    exit(WEXITSTATUS(status));
  return 0;
}
