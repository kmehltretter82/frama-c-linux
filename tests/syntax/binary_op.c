/* run.config
EXIT: 1
OPT:-cpp-extra-args="-DBITWISE"
OPT:-cpp-extra-args="-DMULT"
EXIT: 0
OPT:-cpp-extra-args="-DADD"
OPT:-cpp-extra-args="-DCMP"
*/

#ifdef BITWISE
int v(void) { return 0 & v; }
#endif

#ifdef MULT
int w(void) { return 0 * w; }
#endif

#ifdef ADD
int x(void) { return 0 + x; }
#endif

#ifdef CMP
int y(void) { return 0 <= y; }
#endif
