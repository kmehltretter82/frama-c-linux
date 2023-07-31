/* This example tests the detection of global vars, and the options
   -mt-non-concurrent-accesses and -mt-non-shared-accesses. The variables
   whose name start by u (resp. s) are unshared (resp. shared) */

#include "mthread_pthread.h"
#define NULL ((void*)0)
#define N 5

int u1 = 0; // Used by main before all threads, then by th1
int u2 = 0; // Only used by main
int u3 = 0; // Used by th3 before th31, then by th31

int s4 = 0; // Used by main and th4
int s5 = 0; // Used by th5 and th51
int s6 = 0; // Used by th4 and th6

pthread_t        jobs1;
pthread_t        jobs2;
pthread_t        jobs3;
pthread_t        jobs31;
pthread_t        jobs4;
pthread_t        jobs5;
pthread_t        jobs51;
pthread_t        jobs6;


int random();

void *f1(void *_) {
  int t = u1;
  u1++;
  return NULL;
}

void *f2(void *_) {
  return NULL;
}

void *f31(void* x) {
  int t = u3;
  u3 = 31;
  return NULL;
}

void *f3(void *_) {
  u3 = 3;
  pthread_create( &jobs31 , NULL, f31, NULL);    
  return NULL;
}


void *f4(void *_) {
  int t = s4;
  s4 = 4;

  t = s6;
  s6 = 4;
  return NULL;
}

void *f51(void *x) {
  int t = s5;
  s5 = 51;
  return NULL;
}

void *f5(void *_) {
  pthread_create( &jobs51 , NULL, f51, NULL);
  s5 = 5;
  return NULL;
}


void *f6(void *_) {
  int t = s6;
  s6 = 6;
  return NULL;
}

void main()
{

  int t ;

  u1 = 1;
  t = u1;
  u2 = 1;
  u3 = 1;

  pthread_create( &jobs1 , NULL, f1, NULL);

  u2 = 1;
  t = u2;

  pthread_create( &jobs2 , NULL, f2, NULL);
  pthread_create( &jobs3 , NULL, f3, NULL);

  s4=-1;
  pthread_create( &jobs4 , NULL, f4, NULL);
  s4 = 1;

  pthread_create( &jobs5 , NULL, f5, NULL);
  pthread_create( &jobs6 , NULL, f6, NULL);
}
