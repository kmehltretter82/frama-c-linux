/* run.config
   STDOPT: +"-metrics-eva-cover"
**/

void f() {}

/*@ requires \valid_function(&f); */
int main () {}
