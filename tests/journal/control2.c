/* run.config
  CMXS: control_journal_next2 control_journal2
  EXECNOW: BIN control_journal2.ml @frama-c@ -journal-enable -eva -deps -out -main f -journal-name control_journal2.ml > /dev/null 2> /dev/null
  EXECNOW: LOG control2_sav.res LOG control2_sav.err BIN control_journal_next2.ml @frama-c@ -journal-enable -load-module %{dep:control_journal2.cmxs} -lib-entry -journal-name control_journal_next2.ml > control2_sav.res 2> control2_sav.err
  PLUGIN: callgraph @EVA_CONFIG@
  OPT: -load-module %{dep:control_journal_next2.cmxs}
*/

/* The last OPT was testing reading from byte when generated from native */
int x,y,c,d;

void f() {
  int i;
  for(i=0; i<4 ; i++) {
    if (c) { if (d) {y++;} else {x++;}}
    else {};
    x=x+1;
    }
}
