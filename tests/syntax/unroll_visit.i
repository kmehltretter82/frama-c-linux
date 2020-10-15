/* run.config
   STDOPT: +"-eva @EVA_OPTIONS@ -deps -out -input -deps"
 */
void main() {
   /*@ loop pragma UNROLL 2; */
  for(int i=0; i<100; i++) {
    i--;
    //@ assert i<100;
    i++;
  }
}
