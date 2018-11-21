/* run.config
   STDOPT: #"-loop-max-slevel 999999999999999999"
*/

#define ABS(a) ((a < 0) ? -a : a)

void f1() {
  long i, j, k, err;
  for(i = 0; i < 1000000; i++) {
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
  }
}

void f2() {
  long i, j, k, err;
  for(i = 0; i < 1000000000000000; i++) {
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
  }
}

void f3() {
  long i, j, k, err;
  for(i = 0; i < 64*64*64*64*64; i++) {
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
    for(j = 0; j < 64; j++)
      for(k = 0; k < 64; k++)
        if(ABS(err) > 1);
  }
}
