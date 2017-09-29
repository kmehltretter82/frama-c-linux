/* run.config
   STDOPT: #"-eva-traces-domain -value-msg-key d-traces -slevel 10" +"-then-last -check -print -val"
*/


int loop(int j){
  for(int i = 0; i < 3; i++){
    j ++;
  }
  return j;
}

int main(int c){
  int tmp;
  tmp = 0;
  if (c) tmp = 1;
  else tmp = 2;
  tmp = loop(tmp);
  return tmp;
}
