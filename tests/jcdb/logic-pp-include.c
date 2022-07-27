/* run.config
 COMMENT: test related to a bugfix in the management of relative sub-directories:
 DEPS: logic-pp-include/compile_commands.json
   OPT: -json-compilation-database ./logic-pp-include %{dep:./logic-pp-include/no-stdio.c} -print
*/
