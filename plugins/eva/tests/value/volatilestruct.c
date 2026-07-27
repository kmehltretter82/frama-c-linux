/* run.config*
   STDOPT: -cpp-extra-args="-DSTRUCT=volatile -DPTR="
   STDOPT: -cpp-extra-args="-DSTRUCT=volatile -DPTR=volatile"
   STDOPT: -cpp-extra-args="-DSTRUCT= -DPTR="
   STDOPT: -cpp-extra-args="-DSTRUCT= -DPTR=volatile"
*/

struct ss {
  char *f1;
  int *f2;
  int f3;
};

struct s {
  struct ss f4;
  int f5;
};

/* The four runs test respectively:
   - the struct is volatile but the pointer not: warnings about the pointer
     and the struct values are unknown.
   - the struct and pointer are volatile: no specific volatile warnings, but
     the struct values are unknown.
   - the struct and the pointer are not volatile: no warnings, precise values.
   - the struct is not volatile but the pointer is: same as above. */
PTR struct s *p;
STRUCT struct s s2;

char x;
int y;

void main() {
  p = &s2;

  p->f4.f1 = &x+1;
  p->f4.f2 = &y-3;

  char *q1 = p->f4.f1;
  int *q2 = p->f4.f2;
  int i = p->f5;
  int j = (int) p->f4.f2;

  int r = (&x - p->f4.f1)+1;
  int s = (&y - p->f4.f2)+3;
}
