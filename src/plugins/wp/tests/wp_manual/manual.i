/* run.config
   DONTRUN:
*/
/* run.config_qualif
   OPT: -wp-msg-key shell %{dep:../working_dir/swap.c} %{dep:../working_dir/swap1.h}
   OPT: -wp-msg-key shell -wp-rte %{dep:../working_dir/swap.c} %{dep:../working_dir/swap2.h}
   OPT: -load-module report -kernel-verbose 0 -wp-msg-key shell -wp-rte %{dep:../working_dir/swap.c} %{dep:../working_dir/swap2.h} -wp-verbose 0 -then -no-unicode -report
*/
void look_at_working_dir(void);
