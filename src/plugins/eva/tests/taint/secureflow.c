/* run.config*
 */

#include "__fc_builtin.h"

extern int __attribute__((private)) secret;
extern int __attribute__((private)) extern_data[5];

int __attribute__((public)) global_key[5] = {0, 0, 0, 0, 0};

void f1(void) {
  int local_key[5] = {0, 0, 0, 0, 0};

  for (int i = 0; i < 5; i++) {
    global_key[i] = extern_data[i];
    local_key[i] = extern_data[i];
  }
  /*@ check \tainted(private:global_key); */
  /*@ check \tainted(private:local_key); */
}

/*@ assigns \result \from *x, x; */
extern int assigns_from(int* x);

void f2(void) {
  int zero = 0, one = 1;
  int* ptr = (secret ? &zero : &one);
  /*@ check !\tainted(private:zero); */
  /*@ check !\tainted(private:one); */
  /*@ check \tainted(private:ptr); */

  int __attribute__((public)) v = assigns_from(ptr);
  /*@ check \tainted(private:v); */
}

struct pair {
  int a;
  double b;
};

struct nested {
  int n;
  struct pair p;
};

void f3(void) {
  struct nested s = {0, {1, 2.0}};
  struct nested t = {3, {4, 5.0}};
  struct nested u;

  /*@ check !\tainted(private:s.n); */
  /*@ check !\tainted(private:s.p.a); */
  /*@ check !\tainted(private:s.p.b); */
  /*@ check !\tainted(private:t.n); */
  /*@ check !\tainted(private:t.p.a); */
  /*@ check !\tainted(private:t.p.b); */
  if (secret) {
    u = s;
  } else {
    u = t;
  }
  /*@ check \tainted(private:u.n); */
  /*@ check \tainted(private:u.p.a); */
  /*@ check \tainted(private:u.p.b); */
}

extern int user_input;
int __attribute__((public)) x, y, z;

void f4(void) {
  int* p;

  if (user_input == secret) {
    y = 1;
    /*@ check \tainted(private:y); */
    p = &y;
  } else {
    z = 1;
    /*@ check \tainted(private:z); */
    p = &z;
  }
  x = 1;
  /*@ check !\tainted(private:x); */
  /*@ check \tainted(private:y); */
  /*@ check \tainted(private:z); */

  *p = 1;
  /*@ check \tainted(private:p); */
  /*@ check \tainted(private:*p); */
}

struct foo {
  int x;
  int y;
};

/*@ requires \valid(p);
    assigns p->x;
 */
void write_x(struct foo* p, int a) { p->x = a; }

/*@ requires \valid(p);
    assigns p->y;
 */
void write_y(struct foo* p, int b) { p->y = b; }

void f5(void) {
  struct foo s = {1, 2};
  /*@ check !\tainted(private:s.x); */
  /*@ check !\tainted(private:s.x); */

  if (secret) {
    write_x(&s, 3);
  } else {
    write_y(&s, 4);
  }
  /*@ check \tainted(private:s.x); */
  /*@ check \tainted(private:s.y); */
  /*@ check !\tainted_directly(private:s.x); */
  /*@ check !\tainted_directly(private:s.y); */

  s.x = 0;
  /*@ check !\tainted(private:s.x); */
  if (secret) {
    /*@ assigns s.x; */
    s.x = 1;
  } else {
    /*@ assigns \nothing; */
    __asm__("nop");
  }
  /*@ check \tainted(private:s.x); */
}

int z, w;

void write_z(int z_arg) { z = z_arg; }

void write_w(int w_arg) { w = w_arg; }

struct func_descriptor {
  void (*f)(int);
};

struct func_descriptor funcs[] = {{write_z}, {write_w}};

void f6(void) {
  funcs[0].f(secret);  // write z
  funcs[1].f(42);      // write w

  /*@ check \tainted(private:z); */
  /*@ check !\tainted(private:w); */

  z = w = 0;

  void (*p)(int) = write_z;
  void (*q)(int) = write_w;

  p(secret);  // write z
  q(42);      // write w

  /*@ check \tainted(private:z); */
  /*@ check !\tainted(private:w); */
}

int main(void) {
  f1();
  f2();
  f3();
  f4();
  f5();
  f6();
  return 0;
}