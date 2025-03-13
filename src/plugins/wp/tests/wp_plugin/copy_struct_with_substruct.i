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
    ensures post_eq_struct_fields: a->fi == b->fi && a->fs == (short) 0 && a->fca == b->fca;
    ensures post_eq_struct_with_update: *a == { *b \with .fs = (short)0 };
    ensures post_eq_struct_S_st_T_sti : a->st.sti == b->st.sti ;
    ensures post_eq_struct_S_st_T_sti : a->st.sts == b->st.sts ;
    ensures post_eq_struct_S_st : a->st == b->st ;
    ensures post_eq_struct_S_fca : a->fca == b->fca ;
*/
int
//void
zeroify_S_fs (struct S * a, struct S * b) {
    *a = *b;
    // a->fs = b->fs ^ b->fs ;
    // return a->fi + a->fs + a->fca[4] + a->st.sts + a->st.sti;
    return a->st.sts + a->st.sti;
}
