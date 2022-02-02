/* run.config
<<<<<<< HEAD
   PLUGIN: @EVA_PLUGINS@
   OPT: %{dep:@PTEST_NAME@_1.i} %{dep:@PTEST_NAME@_2.i} -eva @EVA_OPTIONS@
   OPT: %{dep:@PTEST_NAME@_2.i} %{dep:@PTEST_NAME@_1.i} -eva @EVA_OPTIONS@
||||||| 754e522ceb
OPT: @PTEST_DIR@/@PTEST_NAME@_1.i @PTEST_DIR@/@PTEST_NAME@_2.i -eva @EVA_CONFIG@
OPT: @PTEST_DIR@/@PTEST_NAME@_2.i @PTEST_DIR@/@PTEST_NAME@_1.i -eva @EVA_CONFIG@
=======
PLUGIN: eva,scope
OPT: @PTEST_DIR@/@PTEST_NAME@_1.i @PTEST_DIR@/@PTEST_NAME@_2.i -eva @EVA_CONFIG@
OPT: @PTEST_DIR@/@PTEST_NAME@_2.i @PTEST_DIR@/@PTEST_NAME@_1.i -eva @EVA_CONFIG@
>>>>>>> origin/master
*/

extern int a[] ;

/*@ assigns a[3] \from \nothing; */
void g();
