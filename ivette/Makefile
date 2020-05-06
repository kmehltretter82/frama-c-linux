# --------------------------------------------------------------------------
APP=Ivette
DOME=./src/dome
DOME_ARGS=--command $$(dirname $$0)/../../bin/frama-c
DOME_DEV=-server-debug 1
DOME_CLI=./bin/frama-c-gui
DOME_API=./src/frama-c
COPYRIGHT=CEA LIST / LSL
# --------------------------------------------------------------------------

.PHONY: all app dev doc dist typecheck lint

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

# --------------------------------------------------------------------------
# --- Ivette Documentation
# --------------------------------------------------------------------------

# can also use dome-doc to generate Dome-only documentation

D_JSDOC=$(CURDIR)/node_modules/.bin/jsdoc
D_ICONS=$(addprefix $(DOME)/doc/template/gallery-, head.html icons.html tail.html)
D_OUT=./doc/html

doc: $(D_JSDOC) $(D_ICONS)
	@echo "[Ivette] documentation"
	@rm -fr ./build ./doc
	@yarn run build
	@mkdir -p ./doc/html
	@(APP=$(APP) COPYRIGHT="$(COPYRIGHT)" DOME=$(DOME) \
	  yarn exec jsdoc -- -c jsdoc.json -d doc/html)
	@cat $(D_ICONS) > $(D_OUT)/tutorial-icons.html
	@cp -f $(DOME)/doc/gallery.css $(D_OUT)/styles/
	@cp -f $(DOME)/doc/tutorials/*.png $(D_OUT)/
	@echo "[Ivette]   $(D_OUT)/index.html"

tdoc:
	@echo "[Ivette] TypeScript documentation (experimental)"
	@yarn run typedoc
	@echo "[Ivette]   doc/typedoc/index.html"

# --------------------------------------------------------------------------
# --- Ivette Plugins
# --------------------------------------------------------------------------

DOME_PLUGINS=
DOME_EXPORTS=

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
