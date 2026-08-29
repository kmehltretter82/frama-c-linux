// SPDX-License-Identifier: GPL-2.0-only
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/kvm.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static void die(const char *what)
{
	fprintf(stderr, "FRAMA_KVM_SMCCC_SETUP_ERROR %s: %s\n",
		what, strerror(errno));
	exit(EXIT_FAILURE);
}

static int create_vm(void)
{
	int api_version;
	int kvm_fd;
	int vm_fd;

	kvm_fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
	if (kvm_fd < 0)
		die("open /dev/kvm");

	api_version = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
	if (api_version != KVM_API_VERSION) {
		fprintf(stderr,
			"FRAMA_KVM_SMCCC_SETUP_ERROR KVM API version %d\n",
			api_version);
		exit(EXIT_FAILURE);
	}

	vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0);
	if (vm_fd < 0)
		die("KVM_CREATE_VM");
	if (close(kvm_fd))
		die("close /dev/kvm");

	return vm_fd;
}

static int set_filter(int vm_fd, uint32_t base, uint32_t nr_functions,
		      int *saved_errno)
{
	struct kvm_smccc_filter filter = {
		.base = base,
		.nr_functions = nr_functions,
		.action = KVM_SMCCC_FILTER_DENY,
	};
	struct kvm_device_attr attr = {
		.group = KVM_ARM_VM_SMCCC_CTRL,
		.attr = KVM_ARM_VM_SMCCC_FILTER,
		.addr = (uintptr_t)&filter,
	};
	int ret;

	errno = 0;
	ret = ioctl(vm_fd, KVM_SET_DEVICE_ATTR, &attr);
	*saved_errno = errno;
	return ret;
}

static int test_zero_length(void)
{
	int saved_errno;
	int vm_fd = create_vm();
	int ret;

	printf("FRAMA_KVM_SMCCC_ZERO_IOCTL_BEGIN base=0 nr_functions=0\n");
	ret = set_filter(vm_fd, 0, 0, &saved_errno);
	close(vm_fd);

	if (ret == -1 && saved_errno == EINVAL) {
		printf("FRAMA_KVM_SMCCC_ZERO_PASS errno=%d\n", saved_errno);
		return EXIT_SUCCESS;
	}

	printf("FRAMA_KVM_SMCCC_ZERO_FAIL ret=%d observed_errno=%d "
	       "expected_errno=%d\n", ret, saved_errno, EINVAL);
	return EXIT_FAILURE;
}

int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);

	return test_zero_length();
}
