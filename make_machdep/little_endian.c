#if defined(__BYTE_ORDER__)
# if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
__attribute__((section(".data")))
unsigned char little_endian = 0xf4;
# elif __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
__attribute__((section(".data")))
unsigned char little_endian = 0x15;
# else
# error Unexpected __BYTE_ORDER__
# endif
#else
# error __BYTE_ORDER__ undefined
#endif
