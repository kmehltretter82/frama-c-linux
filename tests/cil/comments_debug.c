/* run.config
   FILTER: sed -e "s|/tmp/[^;]*|/tmp/TEMPNAME|g"
   OPT: -add-symbolic-path="$TMPDIR:/tmp" -cpp-command="%{dep:./pp-comments-debug.sh} %i %o" -print -keep-comments -kernel-msg-key parser:comments
*/
/* ABC */
int f() {
  // DEF
  return 1;
}
