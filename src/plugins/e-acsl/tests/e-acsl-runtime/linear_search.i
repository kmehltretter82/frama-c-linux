/* run.config
   COMMENT: linear search (example of the TAP'12 article)
   EXECNOW: LOG gen_linear_search.c BIN gen_linear_search.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/linear_search.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_linear_search.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_linear_search.out ./tests/e-acsl-runtime/result/gen_linear_search.c -lgmp && ./tests/e-acsl-runtime/result/gen_linear_search.out
*/

int A[10];

/*@ requires \forall integer i; 0 <= i < 9 ==> A[i] <= A[i+1]; 
    behavior exists:
      assumes \exists integer j; 0 <= j < 10 && A[j] == elt;
      ensures \result == 1;
    behavior not_exists:
      assumes \forall integer j; 0 <= j < 10 ==> A[j] != elt;
      ensures \result == 0; */
int search(int elt){
  int k;
  // linear search in a sorted array
  for(k = 0; k < 10; k++)
    if(A[k] == elt) return 1; // element found
    else if(A[k] > elt) return 0; // element not found (sorted array)
  return 0; // element not found
} 

int main(void) {

  int found;
  for(int i = 0; i < 10; i++) A[i] = i * i;

  found = search(36);
  /*@ assert found == 1; */

  found = search(5);
  /*@ assert found == 0; */

  return 0;
}
