/* run.config
   COMMENT: structured stmt with several code annotations inside
   EXECNOW: LOG gen_nested_code_annot.c BIN gen_nested_code_annot.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/nested_code_annot.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_nested_code_annot.c > /dev/null &&  gcc -o ./tests/e-acsl-runtime/result/gen_nested_code_annot.out -lgmp ./tests/e-acsl-runtime/result/gen_nested_code_annot.c && ./tests/e-acsl-runtime/result/gen_nested_code_annot.out
*/

int main(void) {
  int x = 0, y = 1;
  /*@ assert x < y; */
  /*@ requires x == 0;
    @ ensures x >= 1; */
  {
    if (x) /*@ assert \false; */ ;
    else {
      /*@ requires x == 0;
	@ ensures x == 1; */
      x++;
      if (x) {
	/*@ requires x == 1;
	  @ ensures x == 2; */
	x++;
      }
      else /*@ assert \false; */ ;
    }
  }
}
