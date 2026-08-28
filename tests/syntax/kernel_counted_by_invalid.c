/* run.config
   EXIT: 1
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DMISSING_COUNTER"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DNON_INTEGRAL_COUNTER"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DFIXED_ARRAY"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DUNION_POINTER"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DFUNCTION_POINTER"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DWRONG_ARGUMENTS"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DPOINTER_TO_FLEX"
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args=-DINVALID_BUILTIN_POINTER"
*/

#ifdef MISSING_COUNTER
struct invalid_missing_counter {
  unsigned count;
  char data[] __attribute__((counted_by(absent)));
};
#endif

#ifdef NON_INTEGRAL_COUNTER
struct invalid_non_integral_counter {
  float count;
  char data[] __attribute__((counted_by(count)));
};
#endif

#ifdef FIXED_ARRAY
struct invalid_fixed_array {
  unsigned count;
  char data[8] __attribute__((counted_by(count)));
};
#endif

#ifdef UNION_POINTER
union invalid_union_pointer {
  unsigned count;
  char *data __attribute__((counted_by(count)));
};
#endif

#ifdef FUNCTION_POINTER
struct invalid_function_pointer {
  unsigned count;
  void (*callback)(void) __attribute__((counted_by(count)));
};
#endif

#ifdef WRONG_ARGUMENTS
struct invalid_wrong_arguments {
  unsigned count;
  char data[] __attribute__((counted_by(count, count)));
};
#endif

#ifdef POINTER_TO_FLEX
struct nested_flexible_array {
  unsigned count;
  char data[];
};

struct invalid_pointer_to_flexible_array {
  unsigned count;
  struct nested_flexible_array *data __attribute__((counted_by(count)));
};
#endif

#ifdef INVALID_BUILTIN_POINTER
void invalid_builtin_pointer(int *pointer)
{
  (void)__builtin_counted_by_ref(pointer);
}
#endif
