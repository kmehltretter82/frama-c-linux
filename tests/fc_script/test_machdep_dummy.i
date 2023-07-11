/* run.config
   NOFRAMAC: Just test the generation of a custom machdep with the installed script.
   COMMENT: This is just a placeholder file for test_machdep.i when clang or yq is unavailable.
   COMMENT: In that case, we don't do the test, but still need to copy a .i file
   COMMENT: to keep the number of files inspected by fc-script identical.
   COMMENT: WARNING: be sure to keep the ENABLED_IF below in sync with test_machdep.i
   ENABLED_IF: (or (not %{bin-available:clang}) (not %{bin-available:yq}))
*/
