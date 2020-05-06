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

doc:
	@echo "[Ivette] documentation"
	@yarn run typedoc

# --------------------------------------------------------------------------
# --- Ivette Plugins
# --------------------------------------------------------------------------

DOME_PLUGINS=
DOME_EXPORTS=

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
