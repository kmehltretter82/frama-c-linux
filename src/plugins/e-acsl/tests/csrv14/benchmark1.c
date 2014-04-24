/* ************************************************************************** */
/* instructions */
/* ************************************************************************** */
/*
   check that each call to [binary_search]:
   o takes as argument:
     - a [length] >= 0; and
     - a fully-allocated and sorted array [a] of (at least) [length] elements
   o returns:
     - either an index [i] s.t. a[i] == key;
     - or -1 if there is no such index
*/
/* ************************************************************************** */

#define LEN 2000000

int binary_search(int* a, int length, int key) {
  int low = 0, high = length - 1;
  while (low<=high) {
    int mid = low + (high - low) / 2;
    if (a[mid] == key) return mid;
    if (a[mid] < key) { low = mid + 1; }
    else { high = mid - 1; }
  }
  return -1;
}

int main(void) {
  int t[LEN];
  int res, i;

  for(i = 0; i < LEN; i++)
    t[i] = 2 * i + 1;
  res = binary_search(t, LEN, 10101);
  if (res != 5050) return 1;
  res = binary_search(t, LEN, 10100);
  if (res != -1) return 2;

  t[LEN / 4] = t[0];
  // an error must be detected on the next function call
  res = binary_search(t, LEN, 101);
  if (res != -1) return 3;

  return 0;
}
