/* run.config
   OPT: -eva -eva-show-progress -scf -eva-show-progress -journal-disable
*/

void *p;

void main() {
  void **q = &p+1;
  void **r = q+1;
  void *s = p + 1;
}
