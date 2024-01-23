struct t {
  int a;
};
typedef struct t t;
__attribute__((visibility("hidden"))) t f() {
  t res = {0};
  return res;
}
