// SPDX-License-Identifier: GPL-2.0-only
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/kvm.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#ifndef MAP_HUGE_SHIFT
#define MAP_HUGE_SHIFT 26
#endif
#ifndef MAP_HUGE_2MB
#define MAP_HUGE_2MB (21 << MAP_HUGE_SHIFT)
#endif

#define HUGEPAGE_SIZE (2UL * 1024 * 1024)
#define GUEST_PHYS_ADDR 0x40000000ULL
#define MTE_GRANULE_SIZE 16

static int fail(const char *operation)
{
	fprintf(stderr, "FRAMA_KVM_MTE_SETUP_ERROR %s: %s\n",
		operation, strerror(errno));
	return EXIT_FAILURE;
}

int main(void)
{
	struct kvm_userspace_memory_region region = {
		.slot = 0,
		.guest_phys_addr = GUEST_PHYS_ADDR,
		.memory_size = HUGEPAGE_SIZE,
	};
	struct kvm_enable_cap enable_mte = {
		.cap = KVM_CAP_ARM_MTE,
	};
	struct kvm_arm_copy_mte_tags copy_tags = {
		.guest_ipa = GUEST_PHYS_ADDR,
		.flags = KVM_ARM_TAGS_FROM_GUEST,
	};
	long page_size = sysconf(_SC_PAGESIZE);
	unsigned char *tags;
	void *memory;
	int kvm_fd;
	int vm_fd;
	int ret;

	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);

	if (page_size <= 0 || page_size % MTE_GRANULE_SIZE) {
		errno = EINVAL;
		return fail("unsupported page size");
	}

	kvm_fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
	if (kvm_fd < 0)
		return fail("open /dev/kvm");

	ret = ioctl(kvm_fd, KVM_CHECK_EXTENSION, KVM_CAP_ARM_MTE);
	if (ret <= 0) {
		errno = EOPNOTSUPP;
		return fail("KVM_CAP_ARM_MTE unavailable");
	}

	vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0);
	if (vm_fd < 0)
		return fail("KVM_CREATE_VM");

	if (ioctl(vm_fd, KVM_ENABLE_CAP, &enable_mte))
		return fail("KVM_ENABLE_CAP KVM_CAP_ARM_MTE");

	memory = mmap(NULL, HUGEPAGE_SIZE, PROT_READ | PROT_WRITE,
		      MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_HUGE_2MB,
		      -1, 0);
	if (memory == MAP_FAILED)
		return fail("mmap 2 MiB hugetlb");

	region.userspace_addr = (uintptr_t)memory;
	if (ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region))
		return fail("KVM_SET_USER_MEMORY_REGION");

	tags = calloc(page_size / MTE_GRANULE_SIZE, 1);
	if (!tags)
		return fail("allocate tag buffer");

	copy_tags.length = page_size;
	copy_tags.addr = tags;

	printf("FRAMA_KVM_MTE_IOCTL_BEGIN\n");
	ret = ioctl(vm_fd, KVM_ARM_MTE_COPY_TAGS, &copy_tags);
	if (ret < 0)
		return fail("KVM_ARM_MTE_COPY_TAGS");
	if (ret != page_size) {
		fprintf(stderr,
			"FRAMA_KVM_MTE_SETUP_ERROR short copy: %d, expected %ld\n",
			ret, page_size);
		return EXIT_FAILURE;
	}

	printf("FRAMA_KVM_MTE_IOCTL_PASS bytes=%d\n", ret);
	free(tags);
	munmap(memory, HUGEPAGE_SIZE);
	close(vm_fd);
	close(kvm_fd);
	return EXIT_SUCCESS;
}
