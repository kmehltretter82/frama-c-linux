int x;
int *t[2];

int main(int i){
  int **ptr = (int **) ((unsigned long) t + i);
  *ptr = &x;
}
