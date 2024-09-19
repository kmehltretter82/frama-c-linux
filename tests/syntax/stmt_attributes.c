/* run.config
  STDOPT:
  EXIT: 1
  STDOPT: #"-cpp-extra-args=-DNO_SPECIFIERS"
*/

void f() {

  /* Label attributes are accepted in Frama-C's parser, but dumped when building
     Cabs. */
  foo: __attribute__((unused));

  #ifdef NO_SPECIFIERS
  /* Parser detect this as a declaration without any specifiers except for GCC's
    attributes specifiers, which is forbidden, so a syntax error is raised.
    Statement attributes are not supported in frama-c except for labels. */
  __attribute__((fallthrough));
  #endif
}
