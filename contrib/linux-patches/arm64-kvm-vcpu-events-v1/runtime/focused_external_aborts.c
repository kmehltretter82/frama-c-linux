// SPDX-License-Identifier: GPL-2.0-only
/*
 * Build the regression added to external_aborts.c as a focused executable.
 *
 * Pass the source path as a quoted preprocessor token, for example:
 *
 *   -DEXTERNAL_ABORTS_SOURCE='"/path/to/external_aborts.c"'
 *
 * Including the upstream selftest source keeps this runner tied to the exact
 * test under review without duplicating its KVM setup or assertions.
 */
#ifndef EXTERNAL_ABORTS_SOURCE
#error "define EXTERNAL_ABORTS_SOURCE to the Linux external_aborts.c path"
#endif

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wreturn-type"
#define main external_aborts_all_tests_main
#include EXTERNAL_ABORTS_SOURCE
#undef main
#pragma GCC diagnostic pop

int main(void)
{
	test_rejected_events();
	return 0;
}
