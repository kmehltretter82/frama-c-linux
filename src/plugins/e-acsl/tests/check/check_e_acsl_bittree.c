#include <check.h>
#include <stdio.h>
#include <math.h>

#include "../../share/e-acsl/memory_model/e_acsl_mmodel_api.h"
#include "../../share/e-acsl/memory_model/e_acsl_bittree.h"

START_TEST (bittree_size_zero)
{

  struct _block bk1 = {.ptr = 1, .size = 0};

  __add_element(&bk1);
  ck_assert_ptr_eq(__get_cont((void*)0), NULL);
  ck_assert_ptr_eq(__get_cont((void*)1), &bk1);
  ck_assert_ptr_eq(__get_cont((void*)2), NULL);
}
END_TEST

START_TEST (bittree_adjacent_simple)
{

  struct _block bk1 = {.ptr = 1, .size = 1};
  __add_element(&bk1);
  ck_assert_ptr_eq(__get_cont((void*)0), NULL);
  ck_assert_ptr_eq(__get_cont((void*)1), &bk1);
  ck_assert_ptr_eq(__get_cont((void*)2), NULL);
}
END_TEST

START_TEST (bittree_adjacent)
{
  struct _block bk1 = {.ptr = 4, .size = 4};
  struct _block bk2 = {.ptr = 8, .size = 4};
  struct _block bk3 = {.ptr = 16, .size = 4};

  __add_element(&bk1);
  __add_element(&bk2);
  __add_element(&bk3);

  struct _block *att_res[20] = {
    NULL, NULL, NULL, NULL,
    &bk1, &bk1, &bk1, &bk1,
    &bk2, &bk2, &bk2, &bk2,
    NULL, NULL, NULL, NULL,
    &bk3, &bk3, &bk3, &bk3
  };

  for (uintptr_t i = 0; i < 20; i++) {
    ck_assert_ptr_eq(__get_cont((void*)i), att_res[i]);
  }

  __remove_element(&bk1);
  __remove_element(&bk2);
  __remove_element(&bk3);
}
END_TEST

Suite *
gen_suite (void)
{
  Suite *s = suite_create ("Gen");

  /* Core test case */
  TCase *tc_core = tcase_create ("tests");
  tcase_add_test (tc_core, bittree_size_zero);
  tcase_add_test (tc_core, bittree_adjacent_simple);
  tcase_add_test (tc_core, bittree_adjacent);
  suite_add_tcase (s, tc_core);

  return s;
}

int
main (void)
{
  int number_failed;
  Suite *s = gen_suite ();
  SRunner *sr = srunner_create (s);
  srunner_run_all (sr, CK_ENV);
  number_failed = srunner_ntests_failed (sr);
  srunner_free (sr);
  return (number_failed == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
