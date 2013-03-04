/*  -*- Last-Edit:  Mon Dec  7 10:31:51 1992 by Tarak S. Goradia; -*- */



# include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

typedef char	bool;
# define false 0
# define true  1
/*# define NULL 0*/

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




/*@ requires \valid_read(j);
  @ behavior b1:
  @  assumes *j >= maxset;
  @  assigns \nothing;
  @  ensures \result == false;
  @ behavior b2:
  @  assumes *j < maxset;
  @  requires \valid(outset+(0..maxset-1));
  @  requires \valid(j);
  @  assigns *j, outset[*j];
  @  ensures j == \old(j)+1;
  @  ensures outset[*j] == c;
  @  ensures \result == true;
  @ complete behaviors;
  @ disjoint behaviors;
  @*/
int addstr(char c, char *outset, int *j, int maxset){
  bool	result;
  
  /* b1 */
  if (*j >= maxset){
    result = false;
  }
  /* b2 */
  else {
    outset[*j] = c;  
    *j = *j + 1;
    result = true;
  }
  return result;
}


/*@ requires \valid_read(i);
  @ requires \valid_read(s+(*i));
  @ behavior b1:
  @  assumes s[*i] != ESCAPE;
  @  assigns \nothing;
  @  ensures \result == s[*i];
  @ behavior b2:
  @  assumes s[*i] == ESCAPE;
  @  assumes s[*i+1] == ENDSTR;
  @  requires \valid_read(s+(*i+1));
  @  assigns \nothing;
  @  ensures \result == ESCAPE;
  @ behavior b3:
  @  assumes s[*i] == ESCAPE;
  @  assumes s[*i+1] == 'n';
  @  requires \valid_read(s+(*i+1));
  @  assigns *i;
  @  ensures \result == NEWLINE;
  @ behavior b4:
  @  assumes s[*i] == ESCAPE;
  @  assumes s[*i+1] == 't';
  @  requires \valid_read(s+(*i+1));
  @  assigns *i;
  @  ensures \result == TAB;
  @ behavior b5:
  @  assumes s[*i] == ESCAPE;
  @  assumes s[*i+1] != ENDSTR;
  @  assumes s[*i+1] != 'n';
  @  assumes s[*i+1] != 't';
  @  requires \valid_read(s+(*i+1));
  @  assigns *i;
  @  ensures \result == s[*i+1];
  @ complete behaviors;
  @ disjoint behaviors;
  @*/
char esc(char *s, int *i){
  char	result;
  
  /* b1 */
  if (s[*i] != ESCAPE){  
    result = s[*i];
  }
  else{
    /* b2 */
    if(s[*i + 1] == ENDSTR){
      result = ESCAPE;
    }
    else{
      *i = *i + 1;
      /* b3 */
      if(s[*i] == 'n'){
	result = NEWLINE;
      }
      else{
	/* b4 */
	if(s[*i] == 't'){
	  result = TAB;
	}
	/* b5 */
	else{
	  result = s[*i];
	}
      }
    }
  }
  return result;
}


/*@ requires \exists int i;
  0 < i && arg[i] == ENDSTR && \valid_read(arg+(0..i-1));
  @ requires \exists int i;
  0 < i && sub[i] == ENDSTR && \valid(sub+(0..i-1));
  @ behavior b2:
  @  assumes \exists int i;
  0 < i && sub[i] == ENDSTR && \valid(sub+(0..i-1)) && i >= MAXPAT;
  @  ensures \result == 0;
  @ behavior b3:
  @  assumes \exists int i;
  0 < i && sub[i] == ENDSTR && \valid(sub+(0..i-1)) && i < MAXPAT;
  @  ensures \result >= 0;
  @ complete behaviors;
  @ disjoint behaviors;
  @*/
int makesub(char* arg, int from, character delim, char* sub){
  int  result;
  int	i, j;
  bool	junk;
  character	escjunk;
  
  j = 0;
  i = from;

  while ((arg[i] != delim) && (arg[i] != ENDSTR)) {
    //@ assert arg[i] != delim;
    //@ assert arg[i] != ENDSTR;
    if ((arg[i] == (unsigned)('&'))){
      junk = addstr(DITTO, sub, &j, MAXPAT);
    }
    else {
      escjunk = esc(arg, &i);
      junk = addstr(escjunk, sub, &j, MAXPAT);
    }
    
    i = i + 1;
  }
  //@ assert arg[i] == delim || arg[i] == ENDSTR;
  /* b1 */
  if (arg[i] != delim){
    // unreachable
    result = 0;
  }else {
    //@ assert arg[i] == delim;
    junk = addstr(ENDSTR, &(*sub), &j, MAXPAT);
    /* b2 */
    if (!junk){
      result = 0;
    }
    /* b3 */
    else{
      result = i;
    }
  }
  return result;
}


/*@ requires \exists int i; 0 < i && arg[i] == ENDSTR && \valid(arg+(0..i-1));
  @ requires \exists int i; 0 < i && sub[i] == ENDSTR && \valid(sub+(0..i-1));
  @*/
bool getsub(char* arg, char* sub){
  int	makeres;
  makeres = makesub(arg, 0, ENDSTR, sub);
  if(makeres > 0){
    return(1);
  }
  else{
    return(0);
  }
}

