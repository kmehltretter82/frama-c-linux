/* run.config*
   STDOPT: +""
   STDOPT: +"-main foo"
   STDOPT: +"-main foo -eva-context-valid-pointers"
 */

volatile unsigned int v;

int main(char*arg,int argc,char *argv[2]) {
  arg[0] = 0;
  arg[1] = 1;
  if (v) { arg[2] = 1;}
  if (!argc) arg[1000]=1000;
  arg[argc] = 4;

  if (v) {
    argv[1] = "5069";
    argv[0] = "5069";
  }

  argv[0][0] = '0';
}

/* Eva creates a base S_A of type int[10][10] pointed to by A:
   - by default, A can be null and validity of S_A is unknown (and cannot be
     reduced by assertions), so alarms are emitted.
   - with -eva-context-valid-pointers, A and S_A[0..9][0..9] are both valid,
     so no alarm is emitted.
   In both cases, the analysis of this program should not fail. */
void foo(int A[10][10]) {
  //@ assert A != \null;
  //@ assert \valid(&A[0..9][0..9]);
  int i = v % 10;
  int j = v % 10;
  int x = A[i][j];
  A[0][0] = 0;
  A[9][9] = 1;
}
