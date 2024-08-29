/* run.config*
PLUGIN: @EVA_PLUGINS@
STDOPT: #"-asm-contracts-ensure-init -print"
*/

int main() {
  int* sp;
  int x;
  asm volatile ("mov %%rsp, %0;":"=r"(sp));
  *(sp - 2) = 3;
  return x;
}
