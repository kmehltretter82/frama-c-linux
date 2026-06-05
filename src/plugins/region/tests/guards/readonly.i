/*@ region *p; */
void readwrite(int *p) { *p = 1; }

/*@ region *p, \validread; */
void validread(int *p) { *p = 1; }
