// compile_commands.json must have "-includestdio.h" and define ZERO

//@ ensures \result == ZERO;
int main(){
  printf("bla\n");
  return ZERO;
}
