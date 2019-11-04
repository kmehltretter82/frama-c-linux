/* run.config
   OPT: -load-script tests/declared/called_in_ghost.ml -print
*/

/*@ assigns \nothing ; */
void function(int e, ...);

void foo(void){
  //@ ghost function(1, 2, 3, 4);
}

/*@ assigns \nothing ; */
int function_wr(int e, ...);

void bar(void){
  //@ ghost int x = function_wr(1, 2);
  //@ ghost x = function_wr(1, 2);
}
