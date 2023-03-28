// double structure with initialisation and pointer
//  no alias

typedef struct
{       
    int   a;
    int   b;
} st_1_t;

typedef struct
{       
    struct struct_1_t*  s;
    int   c;
} st_2_t;


typedef struct
{       
    struct struct_2_t*  t;
    int   d;
} st_3_t;





int main () {

  st_1_t x1 = {0,1};
  st_1_t x2 = {1,2};
  st_2_t y1 = {&x1,3};
  st_2_t y2 = {&x2,4};
  st_3_t z = {&y1,5};
  
  z.t = &y2;
  y1.c = z.d;

  return 0;
}
