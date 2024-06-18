##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2024                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

.ONESHELL:
.PHONY: dev* custom* help push

ifneq (, $(shell which podman))
DOCKER=podman
else
DOCKER=docker
endif

help:
	@echo "Available targets are:"
	echo "- dev.*: public Git development version (no gui)"
	echo "- dev-gui.*: public Git development version (with gui)"
	echo "- dev-stripped.*: public Git development version with minimal size (no gui)"
	echo "- custom.*: version based on a frama-c-*.tar.gz archive (no gui)"
	echo "- custom-gui.*: same as previous, but with gui"
	echo "- custom-stripped.*: same as previous, but with minimal size (no gui)"
	echo "  (custom targets require FRAMAC_ARCHIVE to be set)"
	echo ""
	echo "For each target, the suffix (.*) denotes the Docker base image:"
	echo "- debian: based on debian:trixie-slim"
	echo "          (default image in the Frama-C Docker Hub)"
	echo "- fedora: based on fedora:40"
	echo "- alpine: based on alpine:3.19"
	echo "          (smallest image, but E-ACSL does not work due to musl)"
	echo
	echo "Targets for users with write access to the framac Docker Hub:"
	echo "- push TAG=<tag1> AS=<tag2>: perform a docker push with image"
	echo "  <tag1> sent as <tag2>. Usage example:"
	echo "  make push TAG=framac/frama-c:dev.debian AS=framac/frama-c:dev"
	echo ""
	echo "- dev-push-all: push all variants of dev images"
	echo ""
	echo "- custom-push-all: push all variants of custom archive images"
	echo "  (requires FRAMAC_ARCHIVE to be set)"

DEPS=../../reference-configuration.md Dockerfile *.sh

version=$(shell grep -o "^- OCaml [0-9.]\+" "../../reference-configuration.md" | grep -o "[0-9.]\+")
BUILD_ARGS += --build-arg=OCAML_VERSION=$(version)

%.debian: BUILD_ARGS += --build-arg=DISTRO=debian:trixie-slim
%.fedora: BUILD_ARGS += --build-arg=DISTRO=fedora:40
%.alpine: BUILD_ARGS += --build-arg=DISTRO=alpine:3.19

dev-all: dev.debian dev-stripped.debian dev-gui.debian \
         dev.fedora dev-stripped.fedora dev-gui.fedora \
         dev.alpine dev-stripped.alpine dev-gui.alpine

dev.%: $(DEPS)
	cp ../../reference-configuration.md .
	$(DOCKER) build . -t framac/frama-c:$@ $(BUILD_ARGS) --target frama-c-slim

dev-gui.%: dev.%
	$(DOCKER) build . -t framac/frama-c-gui:dev.$* $(BUILD_ARGS) --target frama-c-gui-slim

dev-stripped.%: dev.%
	$(DOCKER) build . -t framac/frama-c:$@ $(BUILD_ARGS) --target frama-c-stripped

ifeq ($(FRAMAC_ARCHIVE),)
custom.% custom-gui.% custom-stripped.%:
	@echo "error: run '$(MAKE) $@ FRAMAC_ARCHIVE=frama-c-<version>.tar.gz',"
	echo "       where frama-c-<version>.tar.gz is the name of the archive."
	echo "Note: the archive must be in the current directory and be named as"
	echo "      'frama-c-<version>.tar.gz' (where <version> is at your choice)."
	exit 1
else
BUILD_ARGS += --build-arg=from_archive=$(FRAMAC_ARCHIVE)
custom.%: $(DEPS)
	cp ../../reference-configuration.md .
	$(DOCKER) build . -t frama-c-$@ $(BUILD_ARGS) --target frama-c-slim

custom-gui.%: custom.%
	$(DOCKER) build . -t frama-c-$@ $(BUILD_ARGS) --target frama-c-gui-slim

custom-stripped.%: custom.%
	$(DOCKER) build . -t frama-c-$@ $(BUILD_ARGS) --target frama-c-stripped
endif

# check if either TAG or AS are empty
ifeq ($(TAG)$(AS),$(AS)$(TAG))
push:
	@echo "error: run '$(MAKE) $@ TAG=<orig> AS=<new>'"
	echo "        where <tag> is the current tag of the image to be pushed,"
	echo "        and <new> is the name used in the Docker Hub"
	echo "        e.g. framac/frama-c:dev, framac/frama-c-gui:dev, etc."
	echo "(if you supplied identical tags, just run 'docker push $(TAG)')"
	exit 1
else
push:
	$(DOCKER) tag $(TAG) $(AS)
	$(DOCKER) push $(AS)
endif

dev-push-all:
	$(DOCKER) push framac/frama-c:dev.debian
	$(DOCKER) push framac/frama-c:dev-stripped.debian
	$(DOCKER) push framac/frama-c-gui:dev.debian
	$(DOCKER) push framac/frama-c:dev.fedora
	$(DOCKER) push framac/frama-c:dev-stripped.fedora
	$(DOCKER) push framac/frama-c-gui:dev.fedora
	$(DOCKER) push framac/frama-c:dev.alpine
	$(DOCKER) push framac/frama-c:dev-stripped.alpine
	$(DOCKER) push framac/frama-c-gui:dev.alpine
	$(DOCKER) tag framac/frama-c:dev.debian framac/frama-c:dev
	$(DOCKER) tag framac/frama-c:dev-stripped.debian framac/frama-c:dev-stripped
	$(DOCKER) tag framac/frama-c-gui:dev.debian framac/frama-c-gui:dev
	$(DOCKER) push framac/frama-c:dev
	$(DOCKER) push framac/frama-c:dev-stripped
	$(DOCKER) push framac/frama-c-gui:dev

ifeq ($(CUSTOM_VERSION),)
custom-push-all:
	@echo "error: run '$(MAKE) $@ CUSTOM_VERSION=<version>'"
	exit 1
else
ifeq ($(findstring beta,$(CUSTOM_VERSION)),beta)
custom-push-all:
	@echo "error: cannot push a beta archive"
	exit 1
else
custom-push-all:
	@echo "Copy and paste the following commands:"
	echo ""
	echo "$(DOCKER) tag frama-c-custom.debian framac/frama-c:$(CUSTOM_VERSION).debian"
	echo "$(DOCKER) tag frama-c-custom-stripped.debian framac/frama-c:$(CUSTOM_VERSION)-stripped.debian"
	echo "$(DOCKER) tag frama-c-custom-gui.debian framac/frama-c-gui:$(CUSTOM_VERSION).debian"
	echo ""
	echo "$(DOCKER) tag frama-c-custom.fedora framac/frama-c:$(CUSTOM_VERSION).fedora"
	echo "$(DOCKER) tag frama-c-custom-stripped.fedora framac/frama-c:$(CUSTOM_VERSION)-stripped.fedora"
	echo "$(DOCKER) tag frama-c-custom-gui.debian framac/frama-c-gui:$(CUSTOM_VERSION).fedora"
	echo ""
	echo "$(DOCKER) tag frama-c-custom.alpine framac/frama-c:$(CUSTOM_VERSION).alpine"
	echo "$(DOCKER) tag frama-c-custom-stripped.alpine framac/frama-c:$(CUSTOM_VERSION)-stripped.alpine"
	echo "$(DOCKER) tag frama-c-custom-gui.alpine framac/frama-c-gui:$(CUSTOM_VERSION).alpine"
	echo ""
	echo "$(DOCKER) tag framac/frama-c:$(CUSTOM_VERSION).debian framac/frama-c:$(CUSTOM_VERSION)"
	echo "$(DOCKER) tag framac/frama-c:$(CUSTOM_VERSION)-stripped.debian framac/frama-c:$(CUSTOM_VERSION)-stripped"
	echo "$(DOCKER) tag framac/frama-c-gui:$(CUSTOM_VERSION).debian framac/frama-c-gui:$(CUSTOM_VERSION)"
	echo ""
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION).debian"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION)-stripped.debian"
	echo "$(DOCKER) push framac/frama-c-gui:$(CUSTOM_VERSION).debian"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION).fedora"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION)-stripped.fedora"
	echo "$(DOCKER) push framac/frama-c-gui:$(CUSTOM_VERSION).fedora"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION).alpine"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION)-stripped.alpine"
	echo "$(DOCKER) push framac/frama-c-gui:$(CUSTOM_VERSION).alpine"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION)"
	echo "$(DOCKER) push framac/frama-c:$(CUSTOM_VERSION)-stripped"
	echo "$(DOCKER) push framac/frama-c-gui:$(CUSTOM_VERSION)"
endif
endif
