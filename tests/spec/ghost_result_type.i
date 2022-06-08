/*@ ghost
    /@ assigns \result \from \nothing; @/
    int *f(void);
*/

int main(void){
  //@ ghost int* p = f() ;
}
