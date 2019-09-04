/* run.config
   OPT: -no-autoload-plugins -print
   OPT: -cpp-extra-args="-DERROR_LOC_WITH_COMMENTS"
   OPT: -cpp-extra-args="-DALREADY_HAS_ELSE" -print
   OPT: -cpp-extra-args="-DBAD_ANNOT_POSITION"
   OPT: -cpp-extra-args="-DBAD_ONELINE_GHOST_ELSE"
*/

void normal_only_if(int x, int y) {
  if (x) {
    x++;
  }
}

void normal_if_else(int x, int y) {
  if (x) {
    x++;
  } else {
    y++;
  }
}

void normal_if_else_intricated(int x, int y) {
  if (x)
    if (y)
      y++;
    else
      x++;
}

void if_ghost_else_one_line(int x, int y) {
  if (x) {
    x++;
  } //@ ghost else y ++ ;
}

void if_ghost_else_block(int x, int y) {
  if (x) {
    x++;
  } /*@ ghost else {
    y ++ ;
  } */
}

void if_ghost_else_multi_line_block(int x, int y) {
  if (x) {
    x++;
  } /*@ ghost else {
    y ++ ;
    y += x;
    -- y ;
  } */
}

void if_ghost_else_block_comments(int x, int y) {
  if (x) {
    x++;
  } /*@ ghost
    // comment 1
    // comment 2
  else {
    y ++ ;
  } */
}

void normal_if_ghost_else_intricated(int x, int y) {
  if (x)
    if (x)
      x++;
    //@ ghost else y++;
}

#ifdef ERROR_LOC_WITH_COMMENTS // Must check that the line indicated for undeclared "z" is correct

void if_ghost_else_block_comments_then_error(int x, int y) {
  if (x) {
    x++;
  } /*@ ghost
    // comment 1
    // comment 2
  else {
    y ++ ;
  } */

  z = 42;
}

#endif

#ifdef ALREADY_HAS_ELSE 
// Must warn that the ghost else cannot appear since there is already a else
// Thus the ghost else is ignored and the resulting code does not comprise it

void if_ghost_else_block_bad(int x, int y) {
  if (x) {
    x++;
  } /*@ ghost else {
    y ++ ;
  } */
  else {
    y = 42;
  }
}

#endif

#ifdef BAD_ANNOT_POSITION // Syntax error because of the bad position of the annotation

void test(int x, int y){
  if(x){
    x++ ;
  } /*@ ghost
    //@ ensures \true ;
    else {
      y++ ;
    }
  */
}

#endif

#ifdef BAD_ONELINE_GHOST_ELSE // Syntax error because of unterminated ghost one liner

void if_ghost_else_one_line_bad(int x, int y) {
  if (x) {
    x++;
  } //@ ghost else
  y++;
}

#endif
