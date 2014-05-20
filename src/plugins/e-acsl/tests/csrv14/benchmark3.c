/* ************************************************************************** */
/* instructions */
/* ************************************************************************** */
/*
  Check that each call to the function [quicksort] is performed on an array
  correctly allocated for each cell array[i], with left <= i <= right. 
*/
/* ************************************************************************** */

//#include<stdio.h>
#define LEN 10000

void swap(int* array, int i, int j) {
  int tmp = array[i];
  array[i] = array[j];
  array[j] = tmp;
}

int partition (int* array, int left, int right, int pivotIndex) {
  int pivotValue = array[pivotIndex], storeIndex = left, i;
  swap(array, pivotIndex, right);
  for(i = left; i < right; i++) {
    if(array[i] <= pivotValue) {
      swap(array, i, storeIndex);
      storeIndex++;
    }
  }
  swap(array, storeIndex, right);
  return storeIndex;
}

void quicksort(int* array, int left, int right) {
  if(left < right) {
    int pivotIndex = (left+right)/2;
    int pivotNewIndex = partition(array, left, right, pivotIndex);
    quicksort(array, left, pivotNewIndex-1);
    quicksort(array, pivotNewIndex+1, right);
  }
}

void init(int* arr1, int* arr2) {
  int i;

  // filling arrays
  arr1[0] = 0; 
  arr2[0] = 9;
  for(i = 1; i < LEN; i++){
    arr1[i] = (13 * arr1[i-1] + i) % 10; 
    arr2[i] = 9;
  }
}

int main(void) {
  int i;
  int arr[LEN];     // array to be sorted
  int arr_max[LEN]; // array of maximal elements
    
  init(arr, arr_max);

  /* printf("\n Array before quicksort:\n"); */
  /* for (i=0; i < LEN; i++) */
  /*   printf("%d, ",arr[i]); */

  quicksort(arr, 0, LEN-1);  
  
  /* printf("\n Array after quicksort:\n"); */
  /* for (i=0; i < LEN; i++) */
  /*   printf("%d, ",arr[i]); */

  init(arr, arr_max);
 
  /* error to be detected on the next function call. 
     Should be:  quicksort(arr, 0, LEN-1) 
     to prevent an out-of-bound access to arr[LEN] */
  quicksort(arr, 0, LEN);

  return 0;
}
