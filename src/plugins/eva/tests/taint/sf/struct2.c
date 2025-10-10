/*  run.config
    COMMENT: Test (arrays of) nested structs.
*/

struct simple {
    int s_x;
    struct inner {
        int i_y;
    } s_inner;
};

struct array {
    struct inner a_inner[2];
    struct simple a_simple[2];
};

struct multi_array {
    struct array m_a[2];
};

extern int __fc_private secret;

int main(void) {
    struct simple s;
    s.s_x = 42;
    s.s_inner.i_y = 43;

    struct array a;
    a.a_inner[0].i_y = 0;
    a.a_inner[1].i_y = 1;

    a.a_simple[0].s_x = 44;
    /*@ assert security_status(a.a_simple[0].s_x) == public; */
    /*@ assert security_status(a.a_simple[0].s_inner.i_y) == public; */
    a.a_simple[1].s_inner.i_y = secret;
    /* The update of a.a_simple[1].s_inner.i_y did not affect another array
     * element's s_x field, but it did affect another array element's
     * s_inner.i_y field. In other words, the analysis is struct field
     * sensitive even for arrays of structs: Arrays of structs have summary
     * structs that are updated field-sensitively. */
    /*@ assert security_status(a.a_simple[0].s_x) == public; */
    /*@ assert security_status(a.a_simple[0].s_inner.i_y) == private; */

    struct multi_array m;
    m.m_a[0].a_simple[1].s_inner.i_y = 46;

    return m.m_a[0].a_simple[1].s_inner.i_y;
}
