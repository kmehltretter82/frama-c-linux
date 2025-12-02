/* run.config*
   STDOPT: +"-machdep gcc_x86_64"
*/

__int128 shiftr(__uint128_t x) {
  return x >> 2;
}

int main() {
  __uint128_t u = -1;
  __int128 i = u / 2;
  __uint128_t m = (i - u) % 0xffffffffffffffff;
  return shiftr(m);
}
