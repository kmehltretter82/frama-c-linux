/* run.config
   STDOPT: -machdep gcc_x86_64
   STDOPT: -kernel-warn-key c11
*/

/* forward declaration of enum is supported by GCC but nonstandard */

enum e X;
enum e { V };

enum g Y;
typedef enum g { W } g;
