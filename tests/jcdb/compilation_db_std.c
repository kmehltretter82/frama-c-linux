/* run.config
   DEPS: compilation_db_std_command.json
   OPT: -no-frama-c-stdlib -compilation-db %{dep:./compilation_db_std_command.json} -print
   DEPS: compilation_db_std_arguments.json
   OPT: -no-frama-c-stdlib -compilation-db %{dep:./compilation_db_std_arguments.json} -print
*/

#ifdef __STRICT_ANSI__
# error compilation database language mode was not preserved
#endif

#define GNU_OPTIONAL(first, ...) (first, ## __VA_ARGS__)

int gnu_optional = GNU_OPTIONAL(1);
