/* run.config*
PLUGIN: @EVA_PLUGINS@
STDOPT: #"-asm-contracts-ensure-init -inline-stmt-contracts -absolute-valid-range 0x10000000-0xf00000000 -print"
*/

int main() {
  int* sp;
  int x;
  asm volatile ("mov %%rsp, %0;":"=r"(sp));
  *(sp - 2) = 3;
  return x;
}
