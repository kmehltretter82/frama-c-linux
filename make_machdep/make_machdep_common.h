#if __STDC_VERSION__ < 201112L && !defined(__COMPCERT__)
/* Try using a compiler builtin */
#define ALIGNOF alignof
#else
#define ALIGNOF _Alignof
#endif

#if __STDC_VERSION__ >= 201112L || defined(__COMPCERT__)
// Assume _Generic() is supported
# define COMPATIBLE(T1, T2) _Generic(((T1){0}),  \
                                     T2: 0x15,      \
                                     default: 0xf4  \
                                     )
#else
// Expect that __builtin_types_compatible_p exists
# define COMPATIBLE(T1, T2) (__builtin_types_compatible_p(T1, T2) ? 0x15 : 0xf4)
#endif

#define TEST_TYPE_IS_HELPER1(test_type, type) test_type ## _IS_ ## type
#define TEST_TYPE_IS_HELPER2(test_type, type) TEST_TYPE_IS_HELPER1(test_type, type)
#define TEST_TYPE_IS(type) TEST_TYPE_IS_HELPER2(TEST_TYPE, type)

#define TEST_TYPE_MAYBE(type) unsigned char TEST_TYPE_IS(type) = COMPATIBLE(TEST_TYPE, type)
#define TEST_TYPE_MAYBE_(type, type_) unsigned char TEST_TYPE_IS(type_) = COMPATIBLE(TEST_TYPE, type)
