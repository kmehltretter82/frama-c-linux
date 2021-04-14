##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2021                                               #
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
DOME_ARGS=--command $$(dirname $$0)/../../bin/frama-c
DOME_DEV=-server-debug 1
DOME_CLI=./bin/frama-c-gui
DOME_API=./src/frama-c
DOME_CUSTOM_ENTRIES= yes
COPYRIGHT=CEA LIST / LSL
# --------------------------------------------------------------------------

.PHONY: all app dev pkg doc serve dist lint fixlint

all: pkg lint app

app: dome-app
dev: dome-dev
dist: dome-dist

lint: dome-pkg dome-templ
	@echo "[Ivette] running typechecker & linter"
	yarn run typecheck
	yarn run lint

tsc: dome-pkg dome-templ
	@echo "[Ivette] running typechecker & linter (with cache & fix mode)"
	yarn run typecheck
	yarn run lint --fix --cache --cache-location .eslint-cache

# --------------------------------------------------------------------------
# --- Ivette Package Loader
# --------------------------------------------------------------------------

LOADER=src/renderer/loader.ts
PACKAGES=$(shell find src -name "pkg.json")

lint: pkg
dome-pkg: pkg
dome-app: pkg
dome-dev: pkg
dome-dist: pkg
pkg: $(LOADER)
$(LOADER): $(PACKAGES) ./configure.js ./Makefile
	@rm -f $(LOADER)
	@echo "[Ivette] configure packages"
	@node ./configure.js $(LOADER) $(PACKAGES)
	@chmod -f a-w $(LOADER)

# --------------------------------------------------------------------------
# --- Frama-C Source Distrib
# --------------------------------------------------------------------------

SRC_DISTRIB=Makefile.distrib
SRC_HEADERS=headers/header_spec.txt

src-distrib:
	@echo "Generating $(SRC_DISTRIB)"
	@rm -f $(SRC_DISTRIB)
	@rm -f $(SRC_HEADERS)
	@for f in `git ls-files .` ;\
	 do \
		echo "DISTRIB_FILES += \"ivette/$$f\"" >> $(SRC_DISTRIB) ;\
		headers/register.sh "$$f" >> $(SRC_HEADERS) ; \
	 done
	@chmod a-w $(SRC_DISTRIB)
	@chmod a-w $(SRC_HEADERS)

# --------------------------------------------------------------------------
# --- Frama-C API
# --------------------------------------------------------------------------

.PHONY: api

api:
	@echo "[Ivette] Generating TypeScript API"
	@rm -fr src/frama-c/api/generated
	../bin/frama-c.byte -load-module src/frama-c/api/generator.ml -server-tsc
	@find src/frama-c/api/generated -name "*.ts" \
		-exec headache \
			-h ../headers/open-source/CEA_LGPL \
			-c ../headers/headache_config.txt {} \;\
		-exec chmod a-w {} \;

# --------------------------------------------------------------------------
# --- Ivette Documentation
# --------------------------------------------------------------------------

VERSION=$(shell echo "console.log(require('./package.json').version)" | node -)

DOC_ICONS_CSS= src/dome/doc/gallery.css
DOC_ICONS_MAKE= src/dome/doc/iconsmd.js
DOC_ICONS_DATA= src/dome/renderer/controls/gallery.json
DOC_GUIDES= src/dome/doc/guides

NODEBIN= ./node_modules/.bin

doc: $(NODEBIN)/typedoc
	@echo "\n[Ivette] documentation"
	@rm -fr doc/html
	@yarn run typedoc
	@mkdir -p doc/html/guides
	@echo "\n[Ivette] guides"
	@node $(DOC_ICONS_MAKE) $(DOC_ICONS_DATA) > doc/html/guides/icons.md
	@cp $(DOC_ICONS_CSS) doc/html/assets/css/
	@find $(DOC_GUIDES) -name "*.md" -exec cp -f {} doc/html/guides/ \;
	@find doc/html/guides -name "*.md" -print -exec pandoc \
		--standalone --toc --toc-depth=2 --to html \
		--template doc/pandoc/template.html \
		--metadata title="Ivette Documentation" \
		--metadata version="v$(VERSION)" \
		--metadata-file=doc/pandoc/index.json \
		--lua-filter doc/pandoc/href.lua \
		{} -o {}.html \; -delete
	@echo "\n[Ivette] main page"
	@echo "   file://$(PWD)/doc/html/index.html"

# For searching the doc
serve: $(NODEBIN)/serve
	@echo "[Ivette] serve doc documentation"
	@yarn run serve doc/html

$(NODEBIN)/%:
	@echo "[Node] install package $*"
	yarn add -D $*

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
