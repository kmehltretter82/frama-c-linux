/* run.config
   OPT: -print %{dep:./multiple_file_2.c}
*/

/* see bug #43 */

/*@ requires x >= 0; */
extern int f(int x);

/*@ requires x >= 0; */
extern int g(int x);

extern int t1[sizeof(long)];
extern int t2[sizeof(int)];
extern int t3[sizeof(long long)];

struct i_s1 {
    int i1;
    float i2;
};

struct typ1 {
    int tab[sizeof(struct i_s1)];
};

int init_typ1(struct typ1* s);

struct i_s2 {
    float i2;
    int i1;
};

struct typ2 {
    int tab[sizeof(struct i_s2)];
};

int init_typ2(struct typ2* s);

int main () { g(0); t1[0] = 0; t2[0] = 0; t3[0] = 0; return f(0); }
