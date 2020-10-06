/* run.config
  PLUGIN: callgraph
  EXECNOW: BIN control_journal2.ml PTESTS_ITS_NOT_FRAMAC=yes frama-c -no-autoload-plugins -load-plugin from,inout,eva,scope,variadic -journal-enable -eva -deps -out -main f -journal-name control_journal2.ml control2.c > /dev/null 2> /dev/null
  EXECNOW: LOG control2_sav.res LOG control2_sav.err BIN control_journal_next2.ml PTESTS_ITS_NOT_FRAMAC=yes frama-c -no-autoload-plugins -load-plugin from,inout,eva,scope,variadic -journal-enable -load-script %{dep:control_journal2.ml} -lib-entry -journal-name control_journal_next2.ml control2.c  > control2_sav.res 2> control2_sav.err
  CMD: PTESTS_ITS_NOT_FRAMAC=yes frama-c -no-autoload-plugins -load-plugin from,inout,eva,scope,variadic,callgraph
  OPT: -load-script %{dep:control_journal_next2.ml}
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
