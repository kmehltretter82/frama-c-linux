/*run.config
EXIT: 1
   DEPS: ./directory_path/README
   OPT: -add-path %{dep:./file_path} -add-path ./directory_path -add-path ./none
EXIT: 0
 MODULE: empty abstract abstract2
  OPT:
 */
// Note: the dependency  ./directory_path/README is used to create the directory directory_path by the copy_files of the dune file.
