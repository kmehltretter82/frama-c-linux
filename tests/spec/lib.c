/* run.config
   OPT: -cpp-extra-args="-include %{dep:lib.h}" -print -journal-disable
*/

/*@ ensures f((int)0) == (int)0; */
int main () { return 0; }
