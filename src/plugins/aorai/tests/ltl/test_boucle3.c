/* run.config*
   STDOPT: -aorai-ltl %{dep:@PTEST_NAME@.ltl} -aorai-acceptance
*/


int status=0;
int rr=1;
//@ global invariant inv : 0<=rr<=50;

/*@ requires rr<50;
  @ behavior j :
  @  ensures rr<51;
*/
void opa() {
  rr++;
}

void opb () {
  status=1;
}

int main(){

  /*@ loop invariant 0<=rr<=50;
   */
  while (rr<50) {
    opa();
  }

  opb();

  rr=0;
  while (rr<50) {
    opa();
  }

  return 1;
}
