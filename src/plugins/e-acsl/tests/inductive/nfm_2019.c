/* run.config

   COMMENT: from the paper
   COMMENT: Towards Full Proof Automation in Frama-C using Auto-Active Verification
   COMMENT: https://link.springer.com/chapter/10.1007/978-3-030-20652-9_6
*/

/*@

inductive null_vector(int* a, ℤ size) {
  case len_0: ∀ int* a; null_vector(a, 0);
  case len_n: ∀ int* a, ℤ s;
    s > 0 ⇒ null_vector(a+1, s-1) ∧ a[0] == 0 ⇒ null_vector(a, s);
}

*/

// axiom empty_or_not:
//   ∀ int* a, ℤ s;
//     null_vector(a, s) ⇒ (s == 0) ∨ s > 0 ∧ null_vector(a+1, s-1) ∧ a[0] == 0;

int arr[3] = {1, 0, 2};

int main() {
  /*@ assert null_vector((int*)&arr, 0); */
  /*@ assert !null_vector((int*)&arr, 1); */
  /*@ assert !null_vector((int*)&arr, 2); */
  /*@ assert !null_vector((int*)&arr, 3); */
  /*@ assert null_vector((int*)&arr[1], 0); */
  /*@ assert null_vector((int*)&arr[1], 1); */
  /*@ assert !null_vector((int*)&arr[1], 2); */
  /*@ assert null_vector((int*)&arr[2], 0); */
  /*@ assert !null_vector((int*)&arr[2], 1); */
  return 0;
}
