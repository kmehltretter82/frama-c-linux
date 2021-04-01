int f(int a[2]) { return a[1]; }

int g(int a[static 2]) { return a[1]; }

int h(int a[static restrict const 2]) { return a[1]; }
