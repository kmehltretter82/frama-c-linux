/* run.config
   DONTRUN: linked with multiple_file_1.c which is the real test.
*/
/*@ requires y <= 0; */
int g(int y);


struct i_s1 {
    int i1;
    float i2;
};

struct typ1 {
    int tab[sizeof(struct i_s1)];
};

int init_typ1(struct typ1* s);

struct i_s2 {
    int i1;
    float i2;
};

struct typ2 {
    int tab[sizeof(struct i_s2)];
};

int init_typ2(struct typ2* s);

extern int t1[sizeof(long)];
extern int t2[sizeof(long)];
extern int t3[sizeof(long)];
