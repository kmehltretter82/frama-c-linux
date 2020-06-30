/* run.config
STDOPT: +"-dive-from-variables many_values::__retres,many_writes::x"
*/

int t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14;
int *pt[14] = {
  &t1, &t2, &t3, &t4, &t5, &t6, &t7, &t8, &t9, &t10, &t11, &t12, &t13, &t14
};

int many_values(int x)
{
  if (x >= 0 && x < 14)
    return *pt[x];
  else
    return 0;
}

int many_writes()
{
  int x = 0;
  x += t1;
  x += t2;
  x += t3;
  x += t4;
  x += t5;
  x += t6;
  x += t7;
  x += t8;
  x += t9;
  x += t1;
  x += t10;
  x += t11;
  x += t12;
  x += t13;
  x += t14;
  return x;
}

void main(int x)
{
  many_values(x);
  many_writes();
}
