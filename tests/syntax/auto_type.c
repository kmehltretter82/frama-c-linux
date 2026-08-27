/* run.config
   OPT: -print -machdep gcc_x86_64
*/

int value;
const int const_value;
int values[4];
int function(double argument);

void infer_types(void)
{
  __auto_type integer = value;
  __auto_type unqualified = const_value;
  const __auto_type qualified = value;
  __auto_type pointer = values;
  __auto_type function_pointer = function;
  __auto_type side_effect = value++;

  (void)integer;
  (void)unqualified;
  (void)qualified;
  (void)pointer;
  (void)function_pointer;
  (void)side_effect;
}
