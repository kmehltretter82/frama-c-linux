extern int f(void);

int main()
{
    int *p;
    // Keep intermediate cast, which may truncate the pointer value
    int *casted_p = (int *) ((char) p);
    // All pointers have the same size, intermediate cast can be
    // removed, but external cast must be kept, since we're not
    // back to p's original type.
    long *collapse_cast = (long*)((char *)p);
    // Casting to a suitable integer type, then back to original
    // type is a no-op
    int *no_cast_needed_p1 = (int*)((unsigned long)p);
    // Casting to another pointer type, then back to original
    // is a no-op too.
    int *no_cast_needed_p2 = (int*)((char*)p);
    // Conversion between object and function pointer is
    // not allowed in the standard, but seems tolerated
    // by compilers. We emit warnings and keep the casts
    int *obj_fun_obj_ptr = (int*)((int(*)())p);
    int *obj_int_fun_ptr = (int*)(&f);
    // We can remove the intermediate cast, but must emit
    // the appropriate warning as for obj_int_fun_ptr itself.
    int *obj_int_fun_ptr2 = (int*)((unsigned long)f);
    return 0;
}
