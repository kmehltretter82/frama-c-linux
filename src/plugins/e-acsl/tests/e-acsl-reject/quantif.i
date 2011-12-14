/* run.config
   COMMENT: invalid quantifications */

int main(void) {
  int z;
  /*@ assert \forall integer x; x >= 0; */
  /*@ assert \forall integer x; x == 1 ==> x >= 0; */
  /*@ assert \forall int x; 0 <= x ==> x >= 0; */
  /*@ assert \forall float x; 0 <= x <= 3 ==> x >= 0; */
  /*@ assert \forall integer x,y; 0 <= x <= 3 ==> x >= 0; */
  /*@ assert \forall integer x; 0 <= x <= 3 && 0 <= z <= 3 ==> x >= 0; */
  /*@ assert \forall integer x,y; 0 <= x <= 3 || 0 <= y <= 3 ==> x >= 0; */
  /*@ assert \forall int x; 0 <= x+1 <= 3 ==> x >= 0; */
  return 0;
}
