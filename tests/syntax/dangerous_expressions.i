struct s {
  int *a;
};

struct {
  struct s s1[3];
  struct s s2;
} ss;

int f (int t[10] , int n, int *ptr) {
if (t[n]);
if (*ptr);
return 65 ;
}

int main (void) {
int *p=0;
if (*p);
(*p--)/0; // Bug, division is ignored (cf. issue #1529)
ss.s2.a; // not dangerous, remove
ss.s1[2].a; // maybe dangerous, keep
// Bug : Dangerous intermediate expressions are dropped (cf. issue #1529)
int d = (*p/0, (*p--)/0, *p);
return 0 ;
}
