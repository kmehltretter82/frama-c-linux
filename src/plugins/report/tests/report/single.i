/* run.config
   OPT: -load-script %{dep:projectified_status.ml}
   OPT: -load-script %{dep:no_hyp.ml}
   OPT: -load-script %{dep:multi_emitters.ml}
*/

void main() {
  int x = 1;
  /*@ assert \true; */
}
