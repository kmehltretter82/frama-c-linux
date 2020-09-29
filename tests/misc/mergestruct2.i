/* run.config
   OPT: -print -journal-disable %{dep:mergestruct3.i} %{dep:mergestruct1.i}
*/
struct s *p;

void g(void)
{
  p = 0;
}
