# --------------------------------------------------------------------------
APP=Ivette
DOME=src/dome
DOME_ARGS=--command ../bin/frama-c
DOME_APP_CLI=bin/frama-c-gui
DOME_APP_SRC=src/frama-c
COPYRIGHT=CEA LIST / LSL
# --------------------------------------------------------------------------

.PHONY: app dev doc dist

app: dome-app
dev: dome-dev
doc: dome-api dome-doc
dist: dome-dist

# --------------------------------------------------------------------------
# --- Ivette Plugins
# --------------------------------------------------------------------------

DOME_PLUGINS=
DOME_EXPORTS=

# --------------------------------------------------------------------------
include $(DOME)/template/makefile
# --------------------------------------------------------------------------
