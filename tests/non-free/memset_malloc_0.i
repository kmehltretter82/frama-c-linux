/* run.config*

*/

typedef unsigned long size_t;

void *malloc(size_t s);

/*@ assigns ((char*)s)[0..n - 1] \from c;
  @ assigns \result \from s; @*/
extern void *memset(void *s, int c, size_t n);

long *p;

int main(){
  long l;
  p = malloc(0);
  memset(p, 0, 0);
}
