/* run.config
   OPT: -machdep gcc_x86_32 -print
*/

unsigned char bswap16_is_constant[
  __builtin_bswap16(0x0800U) == 0x0008U ? 1 : -1];

unsigned char bswap32_is_constant[
  __builtin_bswap32(0x01020304U) == 0x04030201U ? 1 : -1];

unsigned char bswap64_is_constant[
  __builtin_bswap64(0x0102030405060708ULL) ==
    0x0807060504030201ULL ? 1 : -1];

int classify_protocol(unsigned short protocol)
{
  switch (protocol) {
  case __builtin_bswap16(0x0800U):
    return 1;
  default:
    return 0;
  }
}

unsigned int runtime_bswap32(unsigned int value)
{
  return __builtin_bswap32(value);
}
