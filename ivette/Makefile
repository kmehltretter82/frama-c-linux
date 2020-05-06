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

D_ICONS=$(addprefix $(DOME)/doc/template/gallery-, head.html icons.html tail.html)
D_OUT=doc/html

doc:
	@echo "[Ivette] documentation"
	@rm -fr $(D_OUT)
	@mkdir -p $(D_OUT)
	@yarn run typedoc
	@echo "[Ivette]   $(D_OUT)/index.html"

# --------------------------------------------------------------------------
# --- Ivette Plugins
# --------------------------------------------------------------------------

DOME_PLUGINS=
DOME_EXPORTS=

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
