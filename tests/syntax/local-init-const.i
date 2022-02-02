/*run.config
<<<<<<< HEAD
  PLUGIN: @EVA_PLUGINS@
  OPT: -eva -eva-verbose 0
||||||| 754e522ceb
  OPT: -no-autoload-plugins -load-module eva,scope -eva -eva-verbose 0
=======
PLUGIN: eva,scope
  OPT: -eva -eva-verbose 0
>>>>>>> origin/master
 */

unsigned id(unsigned x) { return x; }

void main() {
  unsigned const r = id(1 > 2 ? 1 : 2);
  //@ assert written_r: r == 2;
}
