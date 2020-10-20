/* run.config
   DONTRUN:
*/
/* run.config_qualif
   PLUGIN: @PLUGIN@ report
   OPT: -add-symbolic-path working_dir:../working_dir -wp-msg-key shell %{dep:../working_dir/swap.c} %{dep:../working_dir/swap1.h}
   OPT: -add-symbolic-path working_dir:../working_dir -wp-msg-key shell -wp-rte %{dep:../working_dir/swap.c} %{dep:../working_dir/swap2.h}
   OPT: -add-symbolic-path working_dir:../working_dir -kernel-verbose 0 -wp-msg-key shell -wp-rte %{dep:../working_dir/swap.c} %{dep:../working_dir/swap2.h} -wp-verbose 0 -then -no-unicode -report
*/
void look_at_working_dir(void);
