int incr(int x) {
  return x + 1;
}

/*@ ensures \result == incr(i); */
int f(int i) {
  return ++i;
}
