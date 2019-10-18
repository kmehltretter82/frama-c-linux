int x,y;
int *t[2] = { &x, &y };

int main(void)
{
  return 1 + (int) * (int*) ((int) t + 2);
}
