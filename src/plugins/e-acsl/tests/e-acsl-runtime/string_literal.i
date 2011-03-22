/* run.config
   COMMENT: string literal
   EXECNOW: LOG gen_string_literal.c BIN gen_string_literal.out FRAMAC_SHARE=./share frama-c -load-module E_ACSL ./tests/e-acsl-runtime/string_literal.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_string_literal.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_string_literal.out ./tests/e-acsl-runtime/result/gen_string_literal.c
*/
void main() {
  /*@ assert "toto" != "titi"; */
}
