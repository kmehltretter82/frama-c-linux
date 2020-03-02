#define M0(x) (x)*(x)<4.0?0.0:1.0
char pixels[] = {M0(0.0), M0(1), M0(2.0f)};

char test_neg = { (-0.) ? 1. : 2. };

char test_ge = { ((-1.) >= 0.) ? 1. : 2. };
