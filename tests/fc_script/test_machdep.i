/* run.config
   NOFRAMAC: Just test the generation of a custom machdep with the installed script.
   COMMENT: No C code gets analyzed there. File is empty on purpose
   ENABLED_IF: %{bin-available:clang}
   FILTER: sed -e '/^version:/d'
   EXECNOW: LOG custom_machdep.yaml LOG make_machdep.err.log PTESTS_TESTING=1 %{bin:frama-c-script} make-machdep --compiler clang --cpp-arch-flags='--target=x86_64' -o custom_machdep.yaml 2> make_machdep.err.log
*/
