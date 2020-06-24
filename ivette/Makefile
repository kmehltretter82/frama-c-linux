# --------------------------------------------------------------------------
APP=Ivette
DOME=./src/dome
DOME_ARGS=--command $$(dirname $$0)/../../bin/frama-c
DOME_DEV=-server-debug 1
DOME_CLI=./bin/frama-c-gui
DOME_API=./src/frama-c
COPYRIGHT=CEA LIST / LSL
# --------------------------------------------------------------------------

.PHONY: all app dev doc serve dist typecheck lint tsc

all: typecheck lint app

app: dome-app
dev: dome-dev
dist: dome-dist

typecheck: dome-pkg dome-templ
	@echo "[Ivette] running ts typechecker"
	yarn run typecheck

lint: dome-pkg dome-templ
	@echo "[Ivette] running ts linter"
	yarn run lint

fixlint: dome-pkg dome-templ
	@echo "[Ivette] running ts linter (with fix)"
	yarn run lint --fix

tsc: typecheck fixlint

# --------------------------------------------------------------------------
# --- Frama-C API
# --------------------------------------------------------------------------

.PHONY: api

api:
	@echo "[Ivette] Generating TypeScript API"
	@find api -name "*.ts" -exec rm -f {} \;
	../bin/frama-c.byte -load-module api/server_tsc.ml -server-tsc
	@find api -name "*.ts" -exec chmod a-w {} \;
	@touch $@

# --------------------------------------------------------------------------
# --- Ivette Documentation
# --------------------------------------------------------------------------

VERSION=$(shell echo "console.log(require('./package.json').version)" | node -)

DOC_ICONS_CSS= src/dome/doc/gallery.css
DOC_ICONS_MAKE= src/dome/doc/iconsmd.js
DOC_ICONS_DATA= src/dome/src/renderer/controls/gallery.json
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
# --- Ivette Plugins
# --------------------------------------------------------------------------

DOME_PLUGINS=
DOME_EXPORTS=

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
