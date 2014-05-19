#include<stdio.h>
#define LEN 2048 

/*@ requires \valid(array+i);
  @ requires \valid(array+j);
  @ assigns array[i], array[j];
  @ ensures array[i] == \old(array[j]);
  @ ensures array[j] == \old(array[i]);
  @*/
void swap(int* array, int i, int j) {
  int tmp = array[i];
  array[i] = array[j];
  array[j] = tmp;
}

/*@ requires \forall integer j; left <= j <= right ==> \valid(array+j);
  @ assigns array[left..right];
  @*/
int partition (int* array, int left, int right, int pivotIndex) {
  int pivotValue = array[pivotIndex], storeIndex = left, i;
  swap(array, pivotIndex, right);
  /*@ loop invariant left <= i <= right;
    @ loop assigns i, storeIndex, array[left..right];
    @ loop variant right-i;
    @*/
  for(i = left; i < right; i++) {
    if(array[i] <= pivotValue) {
      swap(array, i, storeIndex);
      storeIndex++;
    }
  }
  swap(array, storeIndex, right);
  return storeIndex;
}

/*@ requires \forall integer j; left <= j <= right ==> \valid(array+j);
  @ assigns array[left..right];
  @ ensures \forall int i; left <= i < right ==> array[i] <= array[i+1];
  @*/
void quicksort(int* array, int left, int right) {
  if(left < right) {
    int pivotIndex = (left+right)/2;
    int pivotNewIndex = partition(array, left, right, pivotIndex);
    quicksort(array, left, pivotNewIndex-1);
    quicksort(array, pivotNewIndex+1, right);
  }
}

int main(void) {
  int i;
  int arr[LEN];     // array to be sorted
  int arr_max[LEN]; // array of maximal elements

  arr[0] = 0; 
  arr_max[0] = 9;
  for(i = 1; i < LEN; i++){
    arr[i] = (13 * arr[i-1] + i) % 10; 
    arr_max[i] = 9;
  }
    
  printf("\n Array before quicksort:\n");
  for (i=0; i < LEN; i++) 
    printf("%d, ",arr[i]);
  
  quicksort(arr, 0, LEN);  // error ! must be:  quicksort(arr, 0, LEN-1); 
  
  printf("\n Array after quicksort:\n");
  for (i=0; i < LEN; i++) 
    printf("%d, ",arr[i]);

  return 0;
}
