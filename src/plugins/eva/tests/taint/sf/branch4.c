/*  run.config
    COMMENT: Test assignment of array elements in branches
*/

extern int user_input;
extern int __fc_private secret;

int arr[3];

int main(void) {
    if (user_input == secret) {
        arr[1] = 1;
        /*@ assert security_status(arr[1]) == private; */
    } else {
        arr[2] = 1;
        /*@ assert security_status(arr[2]) == private; */
    }
    arr[0] = 1;

    /* The two array fields written directly are necessarily private. */
    /*@ assert security_status(arr[1]) == private; */
    /*@ assert security_status(arr[2]) == private; */

    /* However, field [0], which is written with a public value in a public
     * context, is also treated as private because of the private array
     * summary. */
    /*@ assert security_status(arr[0]) == private; */

    return 0;
}
