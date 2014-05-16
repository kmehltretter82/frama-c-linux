/* ************************************************************************** */
/* instructions */
/* ************************************************************************** */
/*
   check that each call to both functions [*_merge]:
   o takes as argument:
     - [l1] >= 0; and
     - [l2] >= 0; and
     - 2 sorted arrays [t1] and [t2] of length [l1] and [l2] respectively
   o modifies [t3] such that:
     - [t3] is a sorted array of length [l1+l2];
     - each element of [t1] and [t3] belongs to [t3];
     - each element of [t3] belongs to either [t1] or [t2];
*/
/* ************************************************************************** */

/*@ requires l1 >= 0;
  @ requires l2 >= 0;
  @ requires \forall integer i; 0 <= i < l1 - 1 ==> t1[i] <= t1[i+1];
  @ requires \forall integer i; 0 <= i < l2 - 1 ==> t2[i] <= t2[i+1];
  @ ensures \forall integer i; 0 <= i < l1 + l2 - 1 ==> t3[i] <= t3[i+1];
  @ ensures \forall integer i; 0 <= i < l1 ==> 
               \exists integer j; 0 <= j < l1 + l2 && t1[i] == t3[j];
  @ ensures \forall integer i; 0 <= i < l2 ==> 
               \exists integer j; 0 <= j < l1 + l2 && t2[i] == t3[j];
  @ ensures \forall integer i; 0 <= i < l1 + l2 ==> 
               ((\exists integer j; 0 <= j < l1 && t3[i] == t1[j])
               || \exists integer j; 0 <= j < l2 && t3[i] == t2[j]);
  @ */
void correct_merge(int t1[], int t2[], int t3[], int l1, int l2) {
  int i = 0, j = 0, k = 0 ;

  while (i < l1 && j < l2) {
    if (t1[i] < t2[j]) {
      t3[k] = t1[i];
      i++;
    } else {
      t3[k] = t2[j];
      j++;
    }
    k++;
  }
  while (i < l1) {
    t3[k] = t1[i];
    i++;
    k++;
  }
  while (j < l2) {
    t3[k] = t2[j];
    j++;
    k++;
  }
}

/*@ requires l1 >= 0;
  @ requires l2 >= 0;
  @ requires \forall integer i; 0 <= i < l1 - 1 ==> t1[i] <= t1[i+1];
  @ requires \forall integer i; 0 <= i < l2 - 1 ==> t2[i] <= t2[i+1];
  @ ensures \forall integer i; 0 <= i < l1 + l2 - 1 ==> t3[i] <= t3[i+1];
  @ ensures \forall integer i; 0 <= i < l1 ==> 
               \exists integer j; 0 <= j < l1 + l2 && t1[i] == t3[j];
  @ ensures \forall integer i; 0 <= i < l2 ==> 
               \exists integer j; 0 <= j < l1 + l2 && t2[i] == t3[j];
  @ ensures \forall integer i; 0 <= i < l1 + l2 ==> 
               ((\exists integer j; 0 <= j < l1 && t3[i] == t1[j])
               || \exists integer j; 0 <= j < l2 && t3[i] == t2[j]);
  @ */
void wrong_merge(int t1[], int t2[], int t3[], int l1, int l2) {
  int i = 0, j = 0, k = 0 ;

  while (i < l1 && j < l2) {
    if (t1[i] < t2[j]) {
      t3[k] = t1[i];
      i++;
    } else {
      t3[k] = t2[j];
      j++;
    }
    k++;
  }
  while (i < l1) {
    t3[k] = t1[i];
    i++;
    // k++;  // missing instruction
  }
  while (j < l2) {
    t3[k] = t2[j];
    j++;
    k++;
  }
}

#define LEN1 6000
#define LEN2 4000

int main(void) {
  int t1[LEN1], t2[LEN2], t3[LEN1+LEN2], i;

  for(i = 0; i < LEN1; i++)
    t1[i] = 4 * i + 1;

  for(i = 0; i < LEN2; i++)
    t2[i] = 3 * i + 1;

  correct_merge(t1, t2, t3, LEN1, LEN2);

 // an error must be detected on the next function call
  wrong_merge(t1, t2, t3, LEN1, LEN2);

  return 0;
}
