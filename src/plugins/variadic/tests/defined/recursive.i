/* run.config
STDOPT: +"-eva-ignore-recursive-calls"
*/
int f(int a, ...){
  if(a <= 0)
  	return 42;
  else
  	return f(a-1);
}

int main(){
  return  f(7);
}
