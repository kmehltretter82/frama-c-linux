// SPDX-License-Identifier: GPL-2.0-only
#define _GNU_SOURCE

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static void mount_one(const char *source, const char *target,
		      const char *type)
{
	if (mount(source, target, type, 0, NULL) && errno != EBUSY) {
		fprintf(stderr, "FRAMA_KVM_MTE_SETUP_ERROR mount %s: %s\n",
			target, strerror(errno));
		exit(EXIT_FAILURE);
	}
}

static void power_off(void)
{
	sync();
	reboot(RB_POWER_OFF);
	for (;;)
		pause();
}

int main(void)
{
	int status;
	pid_t child;

	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);

	mount_one("devtmpfs", "/dev", "devtmpfs");
	mount_one("proc", "/proc", "proc");
	mount_one("sysfs", "/sys", "sysfs");

	printf("FRAMA_KVM_MTE_RUNTIME_BEGIN\n");

	child = fork();
	if (child < 0) {
		fprintf(stderr, "FRAMA_KVM_MTE_SETUP_ERROR fork: %s\n",
			strerror(errno));
		power_off();
	}

	if (!child) {
		execl("/mte_hugetlb_read", "mte_hugetlb_read", NULL);
		fprintf(stderr, "FRAMA_KVM_MTE_SETUP_ERROR exec: %s\n",
			strerror(errno));
		_exit(127);
	}

	if (waitpid(child, &status, 0) < 0) {
		fprintf(stderr, "FRAMA_KVM_MTE_SETUP_ERROR waitpid: %s\n",
			strerror(errno));
		power_off();
	}

	if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
		printf("FRAMA_KVM_MTE_RUNTIME_RESULT=PASS exit=0\n");
	else if (WIFEXITED(status))
		printf("FRAMA_KVM_MTE_RUNTIME_RESULT=FAIL exit=%d\n",
		       WEXITSTATUS(status));
	else if (WIFSIGNALED(status))
		printf("FRAMA_KVM_MTE_RUNTIME_RESULT=FAIL signal=%d\n",
		       WTERMSIG(status));
	else
		printf("FRAMA_KVM_MTE_RUNTIME_RESULT=FAIL status=%d\n", status);

	power_off();
}
