/* run.config
   PLUGIN: @EVA_PLUGINS@
   STDOPT: +"-eva @EVA_OPTIONS@ -deps -out -input -deps"
 */
typedef char i8; // ideally, pretty-printing should keep 'i8' for some casts
void main() {
   /*@ loop pragma UNROLL 2; */
  for(i8 i=0; i<100; i++) {
    i--;
    //@ assert i<100;
    i++;
  }
}
