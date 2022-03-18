/*run.config
EXIT: 1
   DEPS: @PTEST_DIR@/directory_path/README
   OPT: -add-path %{dep:@PTEST_DIR@/file_path} -add-path @PTEST_DIR@/directory_path -add-path @PTEST_DIR@/none
EXIT: 0
 MODULE: empty abstract abstract2
  OPT:
 */
// Note: the dependency  @PTEST_DIR@/directory_path/README is used to create the directory directory_path by the copy_files of the dune file.
