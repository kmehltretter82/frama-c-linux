/* run.config
   STDOPT: #"-eva-traces-domain -value-msg-key d-traces -slevel 10" +"-then-last -val -print"
*/

#include "__fc_builtin.h"

int g = 42;

int main(int c){
  c = Frama_C_interval(0,1);
  int tmp;
  tmp = 0;
  if (c) tmp = g;
  else tmp = 2;
  for(int i = 0; i < 3; i++){
    tmp ++;
  }
  g = tmp;
  return tmp;
}
