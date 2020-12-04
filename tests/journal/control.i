/* run.config
   COMMENT: do not compare generated journals since they depend on current time

  CMXS: abstract_cpt use_cpt control_journal control_journal_bis abstract_cpt_journal

  EXECNOW: BIN control_journal.ml @frama-c@ -journal-enable -eva -deps -out @EVA_OPTIONS@ -main f -journal-name control_journal.ml > /dev/null 2> /dev/null
  OPT: -load-module %{dep:control_journal.cmxs}

  EXECNOW: BIN control_journal_bis.ml cp %{dep:control_journal.ml} control_journal_bis.ml > /dev/null 2> /dev/null
  OPT: -load-module %{dep:control_journal_bis.cmxs} -calldeps

  EXECNOW: BIN abstract_cpt_journal.ml @frama-c-cmd@ -journal-enable -load-module %{dep:abstract_cpt.cmxs} -load-module %{dep:use_cpt.cmxs} -journal-name abstract_cpt_journal.ml > /dev/null 2> /dev/null
  OPT: -load-module %{dep:abstract_cpt_journal.cmxs} -load-module %{dep:abstract_cpt.cmxs} -load-module %{dep:use_cpt.cmxs}
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
