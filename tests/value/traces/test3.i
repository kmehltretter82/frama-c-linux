/* run.config
   STDOPT: #"-eva-traces-domain -value-msg-key d-traces -slevel 10" +"-then-last -val"
*/

int g;

int main(int c){
  int tmp = 4;
  if(tmp){
    g = tmp;
  } else {
    g = 1;
  }
  return g+1;
}
