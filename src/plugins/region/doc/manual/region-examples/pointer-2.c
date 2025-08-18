void g(short x, int y) {
    short *p = &x;
    *p = 1;
    p = (short *) &y;
    p[0] = 0;
    p[1] = 1;
}
