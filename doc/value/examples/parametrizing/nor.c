int t[2000], i;

void irrelevant_function(void)
{
  for(i=0; i<2000; i++)
    t[i]=i;
}

int main()
{
  irrelevant_function();

  /* now the important stuff: */
  return t[143];
}
