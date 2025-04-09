typedef struct {
  int a;
} A;

typedef struct {
  A a;
  int b;
} B;

typedef struct {
  B b;
  int c;
} C;

const A a = { .a = 1 };
const B b1 = { .a = a, .b = 2 };
const B b2 = { .a = a, .b = 2, .a.a = 3};
const B b3 = { .a.a = 3, .b = 2, .a = a};

const C c1 = { .b = b1, .c = 3 };
const C c2 = { .b = b1, .c = 3, .b.b = 4 };
const C c3 = { .b.b = 4, .c = 3, .b.a.a = 5 };
const C c4 = { .b.b = 4, .c = 3, .b.a.a = 5, .b.a = b3.a };
