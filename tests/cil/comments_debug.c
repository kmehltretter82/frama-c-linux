/* run.config
   FILTER: sed -e "s|$TMPDIR/[^ ]*|/tmp/TEMPNAME|g"
   OPT: -print -keep-comments -kernel-msg-key parser:comments
*/
/* ABC */
int f() {
  // DEF
  return 1;
}
