extern void e_acsl_global_init(void);
extern void __clean(void);
extern void f(void);

int main(void) {
  e_acsl_global_init();
  f();
  __clean();
  return 0;
}
