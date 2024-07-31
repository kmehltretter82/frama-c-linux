#include <limits.h>

//@ import why3: summodule::Sum;

/*@
    requires \abs(a) <= INT_MAX ;
    requires \abs(b) <= INT_MAX ;
    assigns \nothing;
    ensures \result == Sum::sum(a,b);
*/
int sum (int a, int b) {

    /*@
        loop assigns a, b;
        loop invariant a <= a + b;
        loop variant b;
    */
    while( b != 0){
        a+=1;
        b-=1;
    }
    return a;
}
