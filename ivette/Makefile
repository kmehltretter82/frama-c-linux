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

# --------------------------------------------------------------------------
APP=Ivette
DOME=./src/dome
DOME_ARGS=--command $$(dirname $$0)/frama-c
DOME_DEV=-server-debug 1
DOME_CLI=../bin/ivette
DOME_API=./src/frama-c
DOME_CUSTOM_ENTRIES= yes
COPYRIGHT=CEA LIST / LSL
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# --- Ivette Compilation
# --------------------------------------------------------------------------

.PHONY: all app dev

all: pkg lint app
app: api dome-app
dev: api dome-dev

# --------------------------------------------------------------------------
# --- Ivette Linting
# --------------------------------------------------------------------------

.PHONY: lint check-lint check-case

# With autofix
lint: dome-pkg dome-templ check-case
	@echo "[Ivette] running typechecker & linter (with cache & fix mode)"
	yarn run typecheck
	yarn run lint --fix --cache --cache-location .eslint-cache

# Without autofix
check-lint: dome-pkg dome-templ check-case
	@echo "[Ivette] running typechecker & linter"
	yarn run typecheck
	yarn run lint

# In case-insensitive filesystems (macOS/Windows), import statements and
# filenames can have issues due to case differences
check-case:
	@echo "[Ivette] check case issues in imported filenames"
	@err=0 ; for f in `find src | sed -E 's/(.ts|.tsx|.js|.jsx|.css|.json)$$//' | sort -f | uniq -di` ;\
	 do \
		err=1; \
		echo " - ambiguous $$f.*"; \
	 done ;\
	 exit $$err

# --------------------------------------------------------------------------
# --- Help
# --------------------------------------------------------------------------

help::
	@echo "Ivette installation configuration variables"
	@echo "  - PREFIX: used to customize installation path"

# --------------------------------------------------------------------------
# --- Ivette Distribution
# --------------------------------------------------------------------------

.PHONY: dist appimage dist-dir dist-windows dist-macOS dist-linux

dist: dist-dir dome-dist
dist-linux: dist-dir dome-appimage
dist-windows: dist-dir dome-dist-win
dist-macOS: dist-dir dome-dist-mac

dist-dir:
	@echo "Cleaning dist"
	@rm -fr dist

# --------------------------------------------------------------------------
# --- Ivette Package Loader
# --------------------------------------------------------------------------

.PHONY: pkg

LOADER=src/renderer/loader.ts
SANDBOX=src/renderer/sandbox.ts
PACKAGES=$(shell find src -name "pkg.json")
SANDBOXES=$(shell find src/sandbox -name "*.tsx")

dome-pkg: pkg
dome-app: pkg
dome-dev: pkg
dome-dist: pkg
dome-appimage: pkg
dome-dist-win: pkg
dome-dist-mac: pkg

pkg: $(LOADER) $(SANDBOX)

$(LOADER): $(PACKAGES) ./configure.js ./Makefile
	@rm -f $@
	@echo "[Ivette] configure packages"
	@node ./configure.js $@ $(PACKAGES)
	@chmod -f a-w $@

$(SANDBOX): $(SANDBOXES) ./sandboxer.js ./Makefile
	@rm -f $@
	@echo "[Ivette] configure sandboxes"
	@node ./sandboxer.js $@ $(SANDBOXES)
	@chmod -f a-w $@

# --------------------------------------------------------------------------
# --- Frama-C API
# --------------------------------------------------------------------------

.PHONY: api check-api

api:
	@echo "[Ivette] Generating TypeScript API"
	./api.sh build src

check-api:
	@echo "[Ivette] Checking TypeScript API"
	./api.sh check src

# --------------------------------------------------------------------------
# --- Ivette Documentation
# --------------------------------------------------------------------------

.PHONY: icons

VERSION=$(shell echo "console.log(require('./package.json').version)" | node -)

DOC_ICONS_CSS= src/dome/doc/gallery.css
DOC_ICONS_MAKE= src/dome/doc/iconsmd.js
DOC_ICONS_GALLERY= src/dome/doc/guides/icons.md
DOC_ICONS_DATA= src/dome/renderer/controls/gallery.json
DOC_GUIDES= src/dome/doc/guides

NODEBIN= ./node_modules/.bin

DOCDIRS= src/ivette src/dome/renderer src/dome/utils src/frama-c/api
DOCFILES= src/frama-c/server.ts src/frama-c/states.ts $(shell find $(DOCDIRS) -name "*.ts" -or -name "*.tsx")

icons: $(DOC_ICONS_GALLERY)

$(DOC_ICONS_GALLERY): $(DOC_ICONS_MAKE) $(DOC_ICONS_DATA)
	@rm -f $@
	@node $(DOC_ICONS_MAKE) $(DOC_ICONS_DATA) > src/dome/doc/guides/icons.md
	@chmod a-w $@

doc: $(NODEBIN)/typedoc icons
	@echo "\n[Ivette] documentation"
	@rm -fr doc/html
	@yarn run typedoc $(DOCFILES)
	@echo "\n[Ivette] main page"
	@echo ""
	@echo "   file://$(PWD)/doc/html/index.html"
	@echo ""

$(NODEBIN)/%:
	@echo "[Node] install package $*"
	yarn add -D $*

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# --- Ivette Installation
# --------------------------------------------------------------------------

.PHONY: install

BINDIR=$(PREFIX)/bin
LIBDIR=$(PREFIX)/lib

UNAME=$(shell uname)

ifeq ($(UNAME),Darwin)

dome-dist: icon.icns
icon.icns: static/icon.png
	rm -fr icon.iconset
	mkdir icon.iconset
	sips -z 16 16    static/icon.png --out "icon.iconset/icon_16x16.png"
	sips -z 32 32    static/icon.png --out "icon.iconset/icon_16x16@2x.png"
	sips -z 32 32    static/icon.png --out "icon.iconset/icon_32x32.png"
	sips -z 64 64    static/icon.png --out "icon.iconset/icon_32x32@2x.png"
	sips -z 128 128  static/icon.png --out "icon.iconset/icon_128x128.png"
	sips -z 256 256  static/icon.png --out "icon.iconset/icon_128x128@2x.png"
	sips -z 256 256  static/icon.png --out "icon.iconset/icon_256x256.png"
	sips -z 512 512  static/icon.png --out "icon.iconset/icon_256x256@2x.png"
	sips -z 512 512  static/icon.png --out "icon.iconset/icon_512x512.png"
	iconutil -c icns icon.iconset
	rm -fr icon.iconset

endif

IVETTE_DIST=$(wildcard dist/linux-unpacked dist/mac dist/mac-arm64)

ifdef PREFIX
ifeq ($(IVETTE_DIST),dist/linux-unpacked)

install:
	@echo "Installing Ivette (Linux)"
	@mkdir -p $(LIBDIR)/frama-c
	@rm -fr $(LIBDIR)/frama-c/ivette
	@mv $(IVETTE_DIST) $(LIBDIR)/frama-c/ivette
	@mkdir -p $(BINDIR)
	@rm -f $(BINDIR)/ivette
	@ln -s $(LIBDIR)/frama-c/ivette/ivette $(BINDIR)/ivette

else ifeq ($(IVETTE_DIST:-arm64=),dist/mac)

install:
	@echo "Installing Ivette (macOS)"
	@mkdir -p $(LIBDIR)/frama-c
	@rm -fr $(LIBDIR)/frama-c/Ivette.app
	@mv $(IVETTE_DIST)/Ivette.app $(LIBDIR)/frama-c/
	@cp ivette-macos.sh dist/ivette.sh
	@echo "exec open -na $(LIBDIR)/frama-c/Ivette.app --args\\" >> dist/ivette.sh
	@echo "  --command $(BINDIR)/frama-c\\" >> dist/ivette.sh
	@echo "  --working \$$PWD \"\$$@\"" >> dist/ivette.sh
	@mkdir -p $(BINDIR)
	@install dist/ivette.sh $(BINDIR)/ivette
	@rm -fr $(IVETTE_DIST)

else

install:
	@echo "No distribution to install"
	@echo "use 'make dist' and retry"
	@exit 1

endif
else

install:
	@echo "PREFIX not defined"
	@exit 1

endif

# --------------------------------------------------------------------------
# --- Ivette Un-Installation
# --------------------------------------------------------------------------

ifdef PREFIX

uninstall:
	@echo "Uninstall Ivette"
	@rm -f  $(BINDIR)/ivette
	@rm -f  $(LIBDIR)/frama-c/ivette.tgz
	@rm -fr $(LIBDIR)/frama-c/Ivette.app
	@rm -fr $(LIBDIR)/frama-c/ivette

endif

# --------------------------------------------------------------------------
# --- Ivette Tests
# --------------------------------------------------------------------------

tests: dist
	@echo "[Ivette] running tests"
	@dune exec -- yarn playwright test

# --------------------------------------------------------------------------
