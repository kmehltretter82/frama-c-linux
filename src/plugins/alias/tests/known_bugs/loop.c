// leads to a loop in the graph

int main()
{
  for (int i = 0; i < 1; i++) {
    int l[1] = {0};
    int *n_0 = & l[1];
    n_0 = & l[1] + 0;
    int w = 0;
    if (w)
      l[0] = *(& l[1] + 0);
  }
  return 0;
}
