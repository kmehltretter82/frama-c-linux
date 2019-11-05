typedef int int_array [10] ;

struct Type {
  int field ;
} ;

void decl_ghost(void) /*@ ghost (int \ghost * p) */ ;
void def_ghost(void) /*@ ghost (int \ghost * p) */ {}

void decl_not_ghost(void) /*@ ghost (int * p) */ ;
void def_not_ghost(void) /*@ ghost (int * p) */ {}

/*@
  ghost
  /@ assigns \nothing ; @/
  int * function(void) ;
*/

int ng ;
//@ ghost int * gl_gp ;
//@ ghost int \ghost * gl_gpg_1 = &ng ;   // error: address of non-ghost integer into pointer to ghost
//@ ghost int \ghost * gl_gpg_2 = gl_gp ; // error: pointer to a non-ghost location into pointer to ghost


int *gl_p00, *gl_p01, *gl_p02, *gl_p03 ;
// error: we transform pointer to non-ghost into pointer to ghosts
//@ ghost int \ghost * gl_array[4] = { gl_p00, gl_p01, gl_p02, gl_p03 };

void assign(){
  int i ;
  int *p ;
  int a[10];

  //@ ghost int \ghost * gpg1 ;
  //@ ghost int \ghost * gpg2 ;
  //@ ghost int \ghost * gpg3 ;

  /*@
    ghost {
      gpg1 = &i ; // error: address of non-ghost integer into pointer to ghost
      gpg2 = p ;  // error: pointer to a non-ghost location into pointer to ghost
      gpg3 = a ;  // error: array of non-ghost values into pointer to ghost
    }
  */

  int (* nga) [10] ;
  //@ ghost int \ghost (*gpgagi)[10] ;
  //@ ghost gpgagi = nga ; // error: pointer to a non-ghost array into pointer to ghost array


  //@ ghost int \ghost * \ghost * p1 ;
  //@ ghost int        * \ghost * p2 ;
  //@ ghost int * array[10] ;

  //@ ghost p1 = p2 ;         // error: pointer to a pointer to non-ghost into pointer to pointer to ghost
  //@ ghost p1 = array ;      // error: array of pointers to non-ghost into pointer to pointer to ghost

  //@ ghost *p1 = *p2 ;       // error: pointer to non-ghost into pointer to ghost
  //@ ghost *p1 = array[0] ;  // error: pointer to non-ghost into pointer to ghost

  //@ ghost int \ghost * \ghost * \ghost * p3 ;
  //@ ghost int * \ghost (\ghost (*p4))[10] ;
  //@ ghost p3 = p4 ;         // error: pointer to ghost array of ghost pointers to non-ghost
                              //   into pointer to ghost pointers to ghost pointers to ghost

  struct Type ng_var ;
  //@ ghost struct Type g_var ;
  
  int* r_ptr_1 ;
  //@ ghost int \ghost* r_ptr_2 ;

  //@ ghost int* r_ptr_3 = &(g_var.field) ; // error: address of a ghost field into pointer to non-ghost
  //@ ghost r_ptr_2 = &(ng_var.field) ;     // error: address of a non-ghost field into pointer to ghost
}

void init(void){
  int i ;
  int *p ;
  int a[10];

  //@ ghost int \ghost * gpg1 = &i ;  // error: address of non-ghost integer into pointer to ghost
  //@ ghost int \ghost * gpg2 = p ;   // error: pointer to a non-ghost location into pointer to ghost
  //@ ghost int \ghost * gpg3 = a ;   // error: array of non-ghost values into pointer to ghost

  //@ ghost int \ghost * gpg = function() ; // error: pointer to a non-ghost location into pointer to ghost

  int *p00, *p01, *p02, *p03 ;
  //@ ghost int \ghost * array[4] = { p00, p01, p02, p03 };

  //@ ghost int_array ga ;
  //@ ghost int \ghost* ptr = ga ;
}

void call(void){
  int i ;
  decl_ghost() /*@ ghost(&i) */ ; // error: address of non-ghost integer into pointer to ghost
  def_ghost() /*@ ghost(&i) */ ;  // error: address of non-ghost integer into pointer to ghost

  //@ ghost int b = 42 ;
  decl_not_ghost() /*@ ghost(&b) */ ; // error: address of ghost integer into pointer to non-ghost
  def_not_ghost() /*@ ghost(&b) */ ;  // error: address of ghost integer into pointer to non-ghost
}

/*@ ghost
  /@ assigns \nothing ; @/
  void ghost_decl_nothing(int * a) ;

  void ghost_def_nothing(int * a){
    int x = *a ;
  }
*/

void ghost_calls(void){
  //@ ghost int g;
  //@ ghost ghost_decl_nothing(&g);
  //@ ghost ghost_def_nothing(&g);
}