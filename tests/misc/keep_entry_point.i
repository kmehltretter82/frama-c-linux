/* run.config
MODULE: @PTEST_NAME@
OPT: -main f -print
*/

static int f(void);

static int x;

static int y;

static int g() { return y++; }

static int f() { return x++; }
