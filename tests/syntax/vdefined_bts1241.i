/* run.config
<<<<<<< HEAD
STDOPT: +"%{dep:vdefined_bts1241_1.i}"
||||||| 754e522ceb
STDOPT: +"tests/syntax/vdefined_bts1241_1.i"
=======
STDOPT: +"@PTEST_DIR@/vdefined_bts1241_1.i"
>>>>>>> origin/master
 */

int f();

int g() { return 0; }

int f() { return 1; }

int g();

int h();

int h1() { return h(); }
