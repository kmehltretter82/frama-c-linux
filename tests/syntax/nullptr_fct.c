typedef void (*fun)(void);

void wrap (fun f) {
  if (f != (void*)0) f();
  if (f != 0) f();
  if (f != (int*)0) f();
}
