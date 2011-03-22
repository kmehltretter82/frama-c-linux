
/*************/
/* GMP types */
/*************/

typedef struct {
  int _mp_alloc;
  int _mp_size;
  unsigned long int *_mp_d;
} __mpz_struct;

typedef __mpz_struct mpz_t[1];
