# --------------------------------------------------------------------------
APP=Ivette
DOME=./src/dome
DOME_ARGS=--command $$(dirname $$0)/../../bin/frama-c
DOME_DEV=-server-debug 1
DOME_CLI=./bin/frama-c-gui
DOME_API=./src/frama-c
COPYRIGHT=CEA LIST / LSL
# --------------------------------------------------------------------------

.PHONY: app dev doc dist

app: dome-app
dev: dome-dev
doc: dome-doc
dist: dome-dist

# --------------------------------------------------------------------------
# --- Ivette Plugins
# --------------------------------------------------------------------------

DOME_PLUGINS=
DOME_EXPORTS=

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
