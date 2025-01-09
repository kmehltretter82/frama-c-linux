/* run.config
   EXIT: 1
   STDOPT:
*/

/* this is the counterpart of enum_forward.i: we can accept a double typedef
   with of an enum only if the first type is a forward declaration. */

typedef enum h { Z } h;
typedef enum h { Z } h;
h hh = Z;
