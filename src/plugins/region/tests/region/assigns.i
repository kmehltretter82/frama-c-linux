
int B[64];

/*@
    assigns *p \from q, k ;
*/
void modify_by_ref(int** p, int* q, int k) {
    *p = q + k ;
}

int caller_by_ref (int k) {
    int *a;
    modify_by_ref(&a,B,k);
    //*a = 0;
    return *a;
}

/*@
    assigns \result \from q, k ;
*/
int* modify_result(int* q, int k) {
    return q + k ;
}

int caller_result (int k) {
    int *a = modify_result(B,k);
    //*a = 0;
    return *a;
}
