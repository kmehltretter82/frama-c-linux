// TODO: remplacer par un e_acsl.h.in
// faire générer par le makefile un e_acsl.h
// avec des #include "FRAMAC_SHARE/libc/stdio.h", etc

/*************/
/* GMP types */
/*************/

// [TODO] ne pas générer les typedef si on veut linker avec GMP derrière

// [TODO] utiliser un champ modèle de type integer pour modéliser
// l'entier exact correspondant à un mpz_t.
// Not yet implemented in ACSL.

typedef struct {
  int _mp_alloc;
  int _mp_size;
  unsigned long int *_mp_d;
} __mpz_struct;

typedef __mpz_struct mpz_t[1];

/*****************/
/* GMP functions */
/*****************/

// initilializers

/*@ ensures \valid(x);
  @ assigns *x; */
extern void mpz_init(mpz_t x);

/*@ ensures \valid(z);
  @ assigns *z; */
extern void mpz_init_set_ui(mpz_t z, unsigned long int n);

/*@ ensures \valid(z);
  @ assigns *z; */
extern void mpz_init_set_si(mpz_t z, signed long int n);

/*@ ensures \valid(z);
  @ assigns *z; */
extern void mpz_init_set_str(mpz_t z, char *str, int base);

// finalizer

/*@ requires \valid(x);
  @ assigns *x; */
extern void mpz_clear(mpz_t x);

// logical and arithmetic operators

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns \nothing; */
extern int mpz_cmp(mpz_t z1, mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns *z1; */
extern int mpz_comp(mpz_t z1, mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ assigns *z1; */
extern int mpz_neg(mpz_t z1, mpz_t z2);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern int mpz_add(mpz_t z1, mpz_t z2, mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern int mpz_sub(mpz_t z1, mpz_t z2, mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern int mpz_mul(mpz_t z1, mpz_t z2, mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern int mpz_cdiv_q(mpz_t z1, mpz_t z2, mpz_t z3);

/*@ requires \valid(z1);
  @ requires \valid(z2);
  @ requires \valid(z3);
  @ assigns *z1; */
extern int mpz_mod(mpz_t z1, mpz_t z2, mpz_t z3);

/************************/
/* Standard C functions */
/************************/

/*@ terminates \false;
  @ assigns \nothing;
  @ ensures \false; */
extern void exit(int status);

/*@ assigns \nothing; */
extern void eprintf(char *);

/*****************************/
/* Dedicated E-ACSL function */
/*****************************/

void e_acsl_fail(char *msg) { eprintf(msg); exit(1); }
