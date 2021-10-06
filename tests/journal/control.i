/* run.config
 COMMENT: do not compare generated journals since they depend on current time
   EXECNOW: BIN control_journal.ml @frama-c@ -journal-enable -eva -deps -out @EVA_OPTIONS@ -main f -journal-name control_journal.ml > @DEV_NULL@ 2> @DEV_NULL@
 MODULE: control_journal
   OPT:
 MODULE:
   EXECNOW: BIN control_journal_bis.ml cp %{dep:control_journal.ml} control_journal_bis.ml > @DEV_NULL@ 2> @DEV_NULL@
 MODULE: control_journal_bis
   OPT: -calldeps
 MODULE: abstract_cpt use_cpt
   EXECNOW: BIN abstract_cpt_journal.ml @frama-c-cmd@ -journal-enable -journal-name abstract_cpt_journal.ml > @DEV_NULL@ 2> @DEV_NULL@
 MODULE: abstract_cpt_journal abstract_cpt use_cpt
   OPT:
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
