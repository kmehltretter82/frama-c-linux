/* run.config
   CMXS: projectified_status no_hyp multi_emitters
   OPT: -load-module %{dep:projectified_status.cmxs}
   OPT: -load-module %{dep:no_hyp.cmxs}
   OPT: -load-module %{dep:multi_emitters.cmxs}
*/
void main() {
  int x = 1;
  /*@ assert \true; */
}
