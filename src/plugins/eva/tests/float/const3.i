/* run.config*
  STDOPT: #"-kernel-warn-key parser:decimal-float=active"
  STDOPT: #"-kernel-warn-key parser:decimal-float=active -eva-all-rounding-modes-constants -float-hex"
*/

double f1 = 1e-40f;
double d0 = 1e-40;

int main()
{
  Frama_C_dump_each();
  double d1 = f1;
}
