/* run.config
 OPT: -print -journal-disable -kernel-warn-key=annot-error=active
 PLUGIN: @EVA_PLUGINS@
 OPT: -eva @EVA_OPTIONS@ -main g -print -no-annot -journal-disable
 */
//@ assigns *x;
void f(void *x);
void g() {
  int y;
  int* x = &y;
  f(x);
}
