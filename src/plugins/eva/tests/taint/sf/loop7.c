/*  run.config
    COMMENT: Track security status of loops and branches modifying arrays.
    STDOPT: +"-eva-slevel 1"
*/

extern unsigned int __fc_private secret;
extern unsigned int user_input;

int main(void) {
    unsigned int i = 0u;
    int array[10] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    for (i = 1u; i < 10u; i++) {
        /*@ assert security_status(array[i]) == public; */
        array[i] = 1;
    }

    for (i = 1u; i < 10u; i += 3u) {
        if (secret) {
            array[i] = 2;
        }
    }

    for (i = 1u; i < 10u; i++) {
        array[i] = 0;
        // The updates in the previous loop have made the entire array
        // private, and since weak updates are monotone, we cannot make it
        // public again.
        /*@ assert security_status(array[i]) == private; */
    }

    return 0;
}
