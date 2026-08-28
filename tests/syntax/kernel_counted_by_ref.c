/* run.config
   PLUGIN: eva,inout,scope
   OPT: -eva -eva-slevel 20 -machdep gcc_arm64 -cpp-extra-args="-include @FRAMAC_SHARE@/kernel-models/compiler_builtins.h"
*/

struct flex_object {
  unsigned long count;
  unsigned short entries[] __attribute__((counted_by(count)));
};

struct plain_flex_object {
  unsigned long count;
  unsigned short entries[];
};

struct bitfield_flex_object {
  unsigned long count : 8;
  unsigned short entries[] __attribute__((counted_by(count)));
};

struct pointer_object {
  unsigned long count;
  unsigned short *entries __attribute__((counted_by(count)));
};

static struct flex_object counted_object;
static struct plain_flex_object plain_object;
static struct bitfield_flex_object bitfield_object;
static struct pointer_object pointer_object;
static unsigned long fallback_count;
static int counted_calls;
static int plain_calls;

static struct flex_object *get_counted_object(void)
{
  counted_calls++;
  return &counted_object;
}

static struct plain_flex_object *get_plain_object(void)
{
  plain_calls++;
  return &plain_object;
}

static void set_counted(unsigned long count)
{
  *_Generic(__builtin_counted_by_ref(get_counted_object()->entries),
            void *: &fallback_count,
            default:
              __builtin_counted_by_ref(get_counted_object()->entries)) = count;
}

static void set_fallback(unsigned long count)
{
  *_Generic(__builtin_counted_by_ref(get_plain_object()->entries),
            void *: &fallback_count,
            default:
              __builtin_counted_by_ref(get_plain_object()->entries)) = count;
}

int main(void)
{
  unsigned long *counter;
  void *missing;
  int has_counted_by;

  set_counted(7);
  set_fallback(11);
  *__builtin_counted_by_ref(bitfield_object.entries) = 13;
  *__builtin_counted_by_ref(pointer_object.entries) = 17;
  counter = __builtin_counted_by_ref(counted_object.entries);
  missing = __builtin_counted_by_ref(get_plain_object()->entries);
  has_counted_by =
    __builtin_has_attribute(counted_object.entries, counted_by);

  /*@ assert annotated_type_and_address:
        counter == &counted_object.count; */
  /*@ assert annotated_operand_evaluated_once: counted_calls == 1; */
  /*@ assert annotated_write_reaches_counter: counted_object.count == 7; */
  /*@ assert unannotated_result_is_null: missing == \null; */
  /*@ assert unannotated_operand_not_evaluated: plain_calls == 0; */
  /*@ assert generic_fallback_selected: fallback_count == 11; */
  /*@ assert attribute_is_retained: has_counted_by == 1; */
  /*@ assert bitfield_counter_updated: bitfield_object.count == 13; */
  /*@ assert pointer_counter_updated: pointer_object.count == 17; */
  return 0;
}
