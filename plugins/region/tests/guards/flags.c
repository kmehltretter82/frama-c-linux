/* run.config
  OPT: -region -print -cpp-extra-args="-DCALL=spec_default"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_null"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_allocated"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_nullalloc"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_validread"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_nullread"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_garbage"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_nullgarb"
  OPT: -region -print -cpp-extra-args="-DCALL=spec_dummy"
  */

//@ region *a;
void spec_default(int *a);

//@ region *a, \nullable;
void spec_null(int *a);

//@ region *a, \allocated;
void spec_allocated(int *a);

//@ region *a, \nullable, \allocated;
void spec_nullalloc(int *a);

//@ region *a, \validread;
void spec_validread(int *a);

//@ region *a, \nullable, \validread;
void spec_nullread(int *a);

//@ region *a, \garbage;
void spec_garbage(int *a);

//@ region *a, \nullable, \garbage;
void spec_nullgarb(int *a);

//@ region *a, \nullable, \allocated, \validread, \garbage ;
void spec_dummy(int *a);

//@ region *a_default;
void context_default(int *a_default) { CALL(a_default); }

//@ region *a_nullable, \nullable;
void context_nullable(int *a_nullable) { CALL(a_nullable); }

//@ region *a_allocated, \allocated;
void context_allocated(int *a_allocated) { CALL(a_allocated); }

//@ region *a_allocread, \allocated, \validread;
void context_allocread(int *a_allocread) { CALL(a_allocread); }

//@ region *a_nullread, \nullable, \validread;
void context_nullread(int *a_nullread) { CALL(a_nullread); }

//@ region *a_nullalloc, \nullable, \allocated;
void context_nullalloc(int *a_nullalloc) { CALL(a_nullalloc); }

//@ region *a_garbage, \garbage;
void context_garbage(int *a_garbage) { CALL(a_garbage); }

//@ region *a_nullgarb, \nullable, \garbage;
void context_nullgarb(int *a_nullgarb) { CALL(a_nullgarb); }

//@ region *a_dummy, \nullable, \allocated, \validread, \garbage ;
void context_dummy(int *a_dummy) { CALL(a_dummy); }
