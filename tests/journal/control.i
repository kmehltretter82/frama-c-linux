/* run.config
   COMMENT: do not compare generated journals since they depend on current time
   EXECNOW: BIN control_journal.ml BIN control_journal_bis.ml (frama-c -journal-enable -check -eva -deps -out @EVA_CONFIG@ -main f -journal-name control_journal.ml control.i && cp control_journal.ml control_journal_bis.ml) > /dev/null 2> /dev/null
  CMD: frama-c
  OPT: -load-script %{dep:control_journal.ml} -journal-disable
  CMD: frama-c
  OPT: -load-script %{dep:control_journal_bis.ml} -calldeps -journal-disable
  CMXS: abstract_cpt
  EXECNOW: BIN abstract_cpt_journal.ml frama-c -journal-enable -load-module %{dep:abstract_cpt.cmxs} -load-script %{dep:use_cpt.ml} -journal-name abstract_cpt_journal.ml > /dev/null 2> /dev/null
  CMD: frama-c
  OPT: -load-script %{dep:abstract_cpt_journal.ml} -load-module abstract_cpt -load-script %{dep:use_cpt.ml}
*/

int x,y,c,d;

void f() {
  int i;
  for(i=0; i<4 ; i++) {
    if (c) { if (d) {y++;} else {x++;}}
    else {};
    x=x+1;
    }
}
