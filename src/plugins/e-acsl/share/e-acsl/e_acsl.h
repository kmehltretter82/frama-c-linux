// TODO: remplacer par un e_acsl.h.in
// faire générer par le makefile un e_acsl.h
// avec des #include "FRAMAC_SHARE/libc/stdio.h", etc

// [TODO] ne pas générer les typedef si on veut linker avec GMP derrière

// [TODO] utiliser un champ modèle de type integer pour modéliser
// l'entier exact correspondant à un mpz_t.
// Not yet implemented in ACSL.

/************************/
/* Standard C functions */
/************************/

/*@ terminates \false;
  @ assigns \nothing;
  @ ensures \false; */
extern void exit(int status);

/*@ assigns \nothing; */
extern int printf(const char *, ...);

/*****************************/
/* Dedicated E-ACSL function */
/*****************************/

void e_acsl_fail(char *msg) { printf("%s\n", msg); exit(1); }
