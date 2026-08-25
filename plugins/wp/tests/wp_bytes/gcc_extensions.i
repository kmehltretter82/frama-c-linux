/* run.config*
   STDOPT:+"-machdep gcc_x86_64 -wp-model bytes+raw"
*/

__int128 i128 ;
unsigned __int128 u128 ;

void int128(void) {
  i128 = 0x1122334455667788ULL * 2 ;
  u128 = i128 * 2 ;

  //@ check ko: i128 == 0x1122334455667788ULL ;
  //@ check ko: u128 == 0x11223344U ;

  //@ check ok: i128 == 0x1122334455667788ULL * 2 ;
}
