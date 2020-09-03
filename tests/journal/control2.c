/* run.config
  EXECNOW: BIN control_journal2.ml ./bin/toplevel.opt -journal-enable -eva -deps -out -main f -journal-name result/control_journal2.ml control2.c > /dev/null 2> /dev/null
  EXECNOW: LOG control2_sav.res LOG control2_sav.err BIN control_journal_next2.ml FRAMAC_LIB=lib/fc ./bin/toplevel.byte -journal-enable -load-script %{dep:control_journal2} -lib-entry -journal-name control_journal_next2.ml control2.c > ./result/control2_sav.res 2> ./result/control2_sav.err
  CMD: FRAMAC_LIB=lib/fc ./bin/toplevel.byte
  OPT: -load-script result/control_journal_next2
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
