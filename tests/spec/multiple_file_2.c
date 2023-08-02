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

struct typ2 h;

int t = sizeof(h.tab);

int(*p)(int,int);

int v1_ok = sizeof(p);

int(*p1)(int);

int v1_ok_2 = sizeof(p1);

int(f1)(int,int);

int v2 = sizeof(f1);

int(f2)(int);

int v2_ok_2 = sizeof(f2);

enum EN { AB, AC, AD };

int v3 = sizeof(enum EN);
