/* run.config
   COMMENT: function contract
   EXECNOW: LOG gen_function_contract.c BIN gen_function_contract.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/function_contract.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_function_contract.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_function_contract.out ./tests/e-acsl-runtime/result/gen_function_contract.c -lgmp && ./tests/e-acsl-runtime/result/gen_function_contract.out
*/

int X = 0, Y = 2;

// one ensures
/*@ ensures X == 1; */
void f(void) { X = 1; }

// several ensures
/*@ ensures X == 2;
  @ ensures Y == 2; */
void g(void) { X = 2; }

// one requires
/*@ requires X == 2; */
void h(void) { X += 1; }

// several requires
/*@ requires X == 3;
  @ requires Y == 2; */
void i(void) { X += Y; }

// several behaviors
/*@ behavior b1:
  @   requires X == 5;
  @   ensures X == 3;
  @ behavior b2:
  @   requires X == 3 + Y;
  @   requires Y == 2;
  @   ensures X == Y + 1; */
void j(void) { X = 3; }

// mix requires and assumes
/*@ behavior b1:
  @   assumes X == 1;
  @   requires X == 0;
  @ behavior b2:
  @   assumes X == 3;
  @   assumes Y == 2;
  @   requires X == 3;
  @   requires X + Y == 5; */
void k(void) { X += Y; }

// mix ensures + contract on return
/*@ ensures X == 5; */
int l() { 
  /*@ assert Y == 2; */
  return X; 
}

int main(void) {
  f();
  g();
  h();
  i();
  j();
  k();
  l();
  return 0;
}
