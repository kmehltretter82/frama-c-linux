/* run.config
   OPT: -wp-model region -wp-msg-key print-generated -wp-havoc
   OPT: -wp-model region -wp-msg-key print-generated -wp-no-havoc
*/
/* run.config_qualif
   OPT: -wp-model region -wp-havoc
   OPT: -wp-model region -wp-no-havoc
*/


struct S {
    int fi;
    short fs;
    char fca [6];
    struct T {
        int sti;
        short sts;
    } st;
};

/*@ predicate pointed(struct S *p, struct S * q) = p==q || \separated(p,q);
*/

/*@
    requires pointed(a,b);
    ensures *a == *b;
*/
//
int
//void
copy_struct (struct S * a, struct S * b)
{
    *a = *b;
    //
    return a->fi + a->fs + a->fca[3] + a->st.sti + a->st.sts;
}

/**/
/*@
    requires pointed(a,b);
    ensures post_eq_struct_fields: a->fi == b->fi && a->fs == (short) 0 && a->fca == b->fca;
    ensures post_eq_struct_with_update: *a == { *b \with .fs = (short)0 };
*/
int
//void
zeroify_S_fs (struct S * a, struct S * b) {
    *a = *b;
    a->fs = b->fs ^ b->fs ;
    return a->fi + a->fs + a->fca[4] + a->st.sti ;
}
