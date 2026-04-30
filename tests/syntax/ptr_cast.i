extern int f(void);

int main()
{
    int *p;
    int *casted_p = (int *) ((char) p);
    long *collapse_cast = (long*)((char *)p);
    int *no_cast_needed_p1 = (int*)((unsigned long)p);
    int *no_cast_needed_p2 = (int*)((char*)p);
    int *obj_fun_obj_ptr = (int*)((int(*)())p);
    int *obj_int_fun_ptr = (int*)(&f);
    int *obj_int_fun_ptr2 = (int*)((unsigned long)f);
    return 0;
}
