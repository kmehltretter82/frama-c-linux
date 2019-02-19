/* run.config
STDOPT: +"-dive-from main::z,f::x2 -dive-from-function-alarms f,main"
*/

float g;

float f(float x2)
{
  float y;
  for (int i = 0 ; i < 10 ; i++)
  {
    y = x2 + 1.0;
    x2 = y * 2.0;
  }

  return x2;
}

void main()
{
  float (*pf)(float) = &f;

  float x = 3.0 + g;
  float y = f(x);
  float w = (*pf)(x);
  float z = y + w + 1.0;
}

