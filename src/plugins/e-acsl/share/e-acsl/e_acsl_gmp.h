
/*****************/
/* GMP functions */
/*****************/

// initilializers

/*@ ensures \valid(x);
  @ assigns *x; */
extern void mpz_init(mpz_t x);

/*@ ensures \valid(z);
  @ assigns *z; */
extern void mpz_init_set(mpz_t z, const mpz_t z_orig);

/*@ ensures \valid(z);
  @ assigns *z \from n; */
extern void mpz_init_set_ui(mpz_t z, unsigned long int n);

/*@ ensures \valid(z);
  @ assigns *z \from n; */
extern void mpz_init_set_si(mpz_t z, signed long int n);

/*@ ensures \valid(z);
  @ assigns *z; */
extern int mpz_init_set_str(mpz_t z, const char *str, int base);

// finalizer

/*@ requires \valid(x);
  @ assigns *x; */
extern void mpz_clear(mpz_t x);

// logical and arithmetic operators

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns \nothing; */
extern int mpz_cmp(const mpz_t z1, const mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns *z1; */
extern int mpz_comp(mpz_t z1, const mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns *z1; */
extern void mpz_neg(mpz_t z1, const mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void mpz_add(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void mpz_sub(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void mpz_mul(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void mpz_cdiv_q(mpz_t z1, const mpz_t z2, const mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern void mpz_mod(mpz_t z1, const mpz_t z2, const mpz_t z3);

// coercions to C int

/*@ requires \valid(z); 
  @ assigns \nothing; */
extern long mpz_get_si(const mpz_t z);

/*@ requires \valid(z); 
  @ assigns \nothing; */
extern unsigned long mpz_get_ui(const mpz_t z);
