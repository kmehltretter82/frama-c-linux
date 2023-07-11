/* run.config
   NOFRAMAC: Just test the generation of a custom machdep with the installed script.
   COMMENT: No C code gets analyzed there. File is empty on purpose
   COMMENT: WARNING: be sure to keep the ENABLED_IF below in sync with test_machdep_dummy.i
   COMMENT: a disabled file is not copied, and some _other_ tests contain in their oracles
   COMMENT: the number of .{ci} files in the directory...
   ENABLED_IF: (and %{bin-available:clang} %{bin-available:yq})
   FILTER: sed -e '/^version:/d'
   EXECNOW: LOG custom_machdep.yaml LOG make_machdep.err.log PTESTS_TESTING=1 %{bin:frama-c-script} make-machdep --compiler clang --cpp-arch-flags='--target=x86_64' | yq -Y 'del(.version)|del(.custom_defs)' > custom_machdep.yaml 2> make_machdep.err.log
*/
