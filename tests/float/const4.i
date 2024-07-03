/* run.config*
  STDOPT: #"-kernel-warn-key parser:decimal-float=active"
  STDOPT: #"-kernel-warn-key parser:decimal-float=active -eva-all-rounding-modes-constants"
*/

double f1 = 3.4e38f;
double f2 = 3.405e38f;

int main()
{
  Frama_C_dump_each();
  double d2 = f2;
}
