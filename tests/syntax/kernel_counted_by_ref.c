/* run.config
   OPT: -machdep gcc_arm64 -cpp-extra-args="-include @FRAMAC_SHARE@/kernel-models/compiler_builtins.h"
*/

struct flex_object {
  unsigned long count;
  unsigned short entries[];
};

void use_counted_by_fallback(struct flex_object *object, unsigned long count)
{
  *_Generic(__builtin_counted_by_ref(object->entries),
            void *: &(unsigned long){ 0 },
            default: __builtin_counted_by_ref(object->entries)) = count;
}
