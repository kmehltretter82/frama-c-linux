/* run.config
 COMMENT: do not compare generated journals since they depend on current time
 PLUGIN: @EVA_PLUGINS@
   EXECNOW: BIN control_journal.ml @frama-c@ @PTEST_FILE@ -journal-enable -eva -deps -out @EVA_OPTIONS@ -main f -journal-name control_journal.ml > @DEV_NULL@ 2> @DEV_NULL@
   OPT: -load-script control_journal.ml
 MODULE:
   EXECNOW: BIN control_journal_bis.ml cp control_journal.ml control_journal_bis.ml > @DEV_NULL@ 2> @DEV_NULL@
   OPT: -calldeps -load-script control_journal_bis.ml
 MODULE: abstract_cpt use_cpt
   EXECNOW: BIN abstract_cpt_journal.ml @frama-c@ -journal-enable -journal-name abstract_cpt_journal.ml > @DEV_NULL@ 2> @DEV_NULL@
   OPT: -load-script abstract_cpt_journal.ml
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
