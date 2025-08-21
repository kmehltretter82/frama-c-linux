/* run.config
   STDOPT: #"-cpp-extra-args=-DALIGNOF" #"-cpp-extra-args=-DALIGNAS"
   EXIT: 1
   STDOPT: +"-c23" #"-cpp-extra-args=-DALIGNOF"
   STDOPT: +"-c23" #"-cpp-extra-args=-DALIGNAS"
*/

void f(void){
#ifdef ALIGNOF
  int alignof = 42;
#endif
#ifdef ALIGNAS
  int alignas = 42;
#endif
}
