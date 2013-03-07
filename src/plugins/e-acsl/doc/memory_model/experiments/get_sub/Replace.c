/*  -*- Last-Edit:  Mon Dec  7 10:31:51 1992 by Tarak S. Goradia; -*- */



#include "stdio.h"
#include "stdlib.h"

/*
#include <ctype.h>

typedef char	bool;
# define false 0
# define true  1
# define NULL 0

# define MAXSTR 100
# define MAXPAT MAXSTR

# define ENDSTR  '\0'
# define ESCAPE  '@'
# define CLOSURE '*'
# define BOL     '%'
# define EOL     '$'
# define ANY     '?'
# define CCL     '['
# define CCLEND  ']'
# define NEGATE  '^'
# define NCCL    '!'
# define LITCHAR 'c'
# define DITTO   -1
# define DASH    '-'

# define TAB     9
# define NEWLINE 10

# define CLOSIZE 1

typedef char	character;
typedef char string[MAXSTR];
*/



/*@ requires \valid_read(j);
  @ behavior b1:
  @  assumes *j >= maxset;
  @  assigns \nothing;
  @  ensures \result == 0;
  @ behavior b2:
  @  assumes *j < maxset;
  @  requires \valid(j);
  @  requires \valid(outset+(*j));
  @  assigns *j, outset[*j];
  @  ensures *j == \old(*j)+1;
  @  ensures outset[*j-1] == c;
  @  ensures \result == 1;
  @ complete behaviors;
  @ disjoint behaviors;
  @*/
int addstr(char c, char *outset, int *j, int maxset){
  char	result;
  
  /* b1 */
  if (*j >= maxset){
    //@ assert *j >= maxset;
    result = 0;
  }
  /* b2 */
  else {
    //@ assert *j < maxset;
    outset[*j] = c;
    //@ ghost int tmp = *j;
    *j = *j + 1;
    //@ assert *j == tmp + 1;
    result = 1;
  }
  return result;
}


/*@ requires \valid_read(i);
  @ requires \valid_read(s+(*i));
  @ behavior b1:
  @  assumes s[*i] != '@';
  @  assigns \nothing;
  @  ensures \result == s[*i];
  @ behavior b2:
  @  assumes s[*i] == '@';
  @  assumes s[*i+1] == '\0';
  @  requires \valid_read(s+(*i+1));
  @  assigns \nothing;
  @  ensures \result == '@';
  @ behavior b3:
  @  assumes s[*i] == '@';
  @  assumes s[*i+1] == 'n';
  @  requires \valid_read(s+(*i+1));
  @  assigns *i;
  @  ensures *i == \old(*i)+1;
  @  ensures \result == 10;
  @ behavior b4:
  @  assumes s[*i] == '@';
  @  assumes s[*i+1] == 't';
  @  requires \valid_read(s+(*i+1));
  @  assigns *i;
  @  ensures *i == \old(*i)+1;
  @  ensures \result == 9;
  @ behavior b5:
  @  assumes s[*i] == '@';
  @  assumes s[*i+1] != '\0';
  @  assumes s[*i+1] != 'n';
  @  assumes s[*i+1] != 't';
  @  requires \valid_read(s+(*i+1));
  @  assigns *i;
  @  ensures *i == \old(*i)+1;
  @  ensures \result == s[*i];
  @ complete behaviors;
  @ disjoint behaviors;
  @*/
char esc(char *s, int *i){
  char	result;
  
  /* b1 */
  if (s[*i] != '@'){
    //@ assert s[*i] != '@';
    result = s[*i];
  }
  else{
    //@ assert s[*i] == '@';
    /* b2 */
    if(s[*i + 1] == '\0'){
      //@ assert s[*i+1] == '\0';
      result = '@';
    }
    else{
      //@ assert s[*i+1] != '\0';
      //@ ghost int tmp = *i;
      *i = *i + 1;
      //@ assert *i == tmp + 1;
      /* b3 */
      if(s[*i] == 'n'){
	//@ assert s[*i] == 'n';
	result = 10;
      }
      else{
	//@ assert s[*i] != 'n';
	/* b4 */
	if(s[*i] == 't'){
	  //@ assert s[*i] == 't';
	  result = 9;
	}
	/* b5 */
	else{
	  //@ assert s[*i] != 't';
	  result = s[*i];
	}
      }
    }
  }
  return result;
}


int makesub(char* arg, int from, char delim, char* sub){
  int  result;
  int	i, j;
  char	junk;
  char	escjunk;
  
  j = 0;
  i = from;

  while ((arg[i] != delim) && (arg[i] != '\0')) {
    //@ assert arg[i] != delim;
    //@ assert arg[i] != '\0';
    if ((arg[i] == (unsigned)('&'))){
      //@ assert arg[i] == '&';
      junk = addstr(-1, sub, &j, 100);
    }
    else {
      //@ assert arg[i] != '&';
      escjunk = esc(arg, &i);
      junk = addstr(escjunk, sub, &j, 100);
    }
    
    //@ ghost int tmp = i;
    i = i + 1;
    //@ assert i == tmp + 1;
  }
  //@ assert arg[i] == delim || arg[i] == '\0';
  /* b1 */
  if (arg[i] != delim){
    //@ assert arg[i] != delim;
    // unreachable
    result = 0;
  }else {
    //@ assert arg[i] == delim;
    junk = addstr('\0', &(*sub), &j, 100);
    /* b2 */
    if (!junk){
      //@ assert !junk;
      result = 0;
    }
    /* b3 */
    else{
      //@ assert junk;
      result = i;
    }
  }
  return result;
}


char getsub(char* arg, char* sub){
  int	makeres;
  makeres = makesub(arg, 0, '\0', sub);
  //@ ghost char* tmp_arg = arg;
  //@ ghost char* tmp_sub = sub;
  //@ ghost int verdict = 1;
  /*@ ghost while (*tmp_arg != 0) {
      if(*tmp_arg == '&') {
        if(*tmp_sub != -1){verdict=0;break;}
	tmp_arg++; tmp_sub++;
      }
      else if(*tmp_arg == '@' && *(tmp_arg+1) == '\0') {
        if(*tmp_sub != '@') {verdict=0;break;}
	tmp_arg++; tmp_sub++;
      }
      else if(*tmp_arg == '@' && *(tmp_arg+1) == 'n') {
        if(*tmp_sub != 10) {verdict=0;break;}
        tmp_arg += 2; tmp_sub++;
      }
      else if(*tmp_arg == '@' && *(tmp_arg+1) == 't') {
        if(*tmp_sub != 9) {verdict=0;break;}
        tmp_arg += 2; tmp_sub++;
      }
      else if(*tmp_arg == '@') {
        if(*tmp_sub != *(tmp_arg+1)) {verdict=0;break;}
        tmp_arg += 2; tmp_sub++;
      }
      else {
        if(*tmp_sub != *tmp_arg) {verdict=0;break;}
        tmp_arg++; tmp_sub++;
      }
    } */

  //@ assert verdict == 1;
  if(makeres > 0){
    //@ assert makeres > 0;
    return(1);
  }
  else{
    //@ assert makeres <= 0;
    return(0);
  }
}
