
/*@
    assigns *p \from q, k ;
*/
void modify_by_ref(int** p, int* q, int k, int* b) {
    *p = b == 0 ? q + k : q ;
}

void caller_by_ref () {
    int *a, b, k;
    modify_by_ref(&a,&b,k,0);
    *a = 0;
}

/*@
    assigns \result \from q, k ;
*/
int* modify_result(int* q, int k) {
    return q + k ;
}

void caller_result () {
    int b, k;
    int *a = modify_result(&b,k);
    *a = 0;
}
