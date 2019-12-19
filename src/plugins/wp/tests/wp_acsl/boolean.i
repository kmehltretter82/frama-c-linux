/* run.config
DONTRUN: only usable in qualif config
*/
 /*@
        logic boolean u8_continue_f(unsigned char b) =
          0x80<=b && 0xC0 > b;
    */

    /*@
        assigns \nothing;
        ensures  u8_continue_f(b) == \result;
    */
    int u8_is_continue(const unsigned char b)
    {
        return b >= 0x80 && b <= 0xBF;
    }
