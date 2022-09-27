##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2022                                               #
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
.PHONY: dev* custom* help

help:
	@echo "Available targets are:"
	echo "- dev.*: public Git development version (no gui)"
	echo "- dev-gui.*: public Git development version (with gui)"
	echo "- dev-stripped.*: public Git development version with minimal size (no gui)"
	echo "- custom.*: version based on a frama-c-*.tar.gz archive (no gui)"
	echo "- custom-gui.*: same as previous, but with gui"
	echo "- custom-stripped.*: same as previous, but with minimal size (no gui)"
	echo ""
	echo "For each target, the suffix (.*) denotes the Docker base image:"
	echo "- debian: based on debian:bullseye-slim"
	echo "          (default image in the Frama-C Docker Hub)"
	echo "- fedora: based on fedora:36"
	echo "- alpine: based on alpine:3.16"
	echo "          (smallest image, but E-ACSL does not work due to musl)"

DEPS=../../reference-configuration.md Dockerfile *.sh

version=$(shell grep -o "^- OCaml [0-9.]\+" "../../reference-configuration.md" | grep -o "[0-9.]\+")
BUILD_ARGS := --build-arg=OCAML_VERSION=$(version)

%.debian: BUILD_ARGS += --build-arg=DISTRO=debian:bullseye-slim
%.fedora: BUILD_ARGS += --build-arg=DISTRO=fedora:36
%.alpine: BUILD_ARGS += --build-arg=DISTRO=alpine:3.16

dev.%: $(DEPS)
	cp ../../reference-configuration.md .
	docker build . -t framac/frama-c:$@ $(BUILD_ARGS) --target frama-c-slim

dev-gui.%: dev.%
	docker build . -t framac/frama-c-gui:dev.$* $(BUILD_ARGS) --target frama-c-gui-slim

dev-stripped.%: dev.%
	docker build . -t framac/frama-c:$@ $(BUILD_ARGS) --target frama-c-stripped

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
	docker build . -t frama-c-$@ $(BUILD_ARGS) --target frama-c-slim

custom-gui.%: custom.%
	docker build . -t frama-c-$@ $(BUILD_ARGS) --target frama-c-gui-slim

custom-stripped.%: custom.%
	docker build . -t frama-c-$@ $(BUILD_ARGS) --target frama-c-stripped
endif
