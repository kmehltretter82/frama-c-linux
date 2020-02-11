# --------------------------------------------------------------------------
# ---  Main Makefile for building Dome applications
# --------------------------------------------------------------------------

# DOMEMK_ reserved for makefile derived variables

APP?=$(shell basename $(PWD))
COPYRIGHT?=CEA Tech

DOME?=dome
DOME_ARGS?=
DOME_EXPORTS?=
DOME_PLUGINS?=
DOME_DOC?=html/dome
DOME_APP_CLI?=bin/$(shell echo $(APP) | tr [:upper:] [:lower:])
DOME_APP_DOC?=html/$(shell echo $(APP) | tr [:upper:] [:lower:])
DOME_APP_SRC?=src/renderer

# --------------------------------------------------------------------------
# ---  Makefile Help
# --------------------------------------------------------------------------

.PHONY: dome-help

dome-help:
	@echo
	@echo "[Dome] Builtin Targets:"
	@echo "  make dome-help    This help"
	@echo "  make dome-dev     Run application in development mode"
	@echo "  make dome-app     Compile application"
	@echo "  make dome-dist    Package application for production"
	@echo "  make dome-doc     Generate Dome documentation"
	@echo "  make dome-api     Generate Application documentation"
	@echo "  make dome-pkg     Install development packages"
	@echo "  make dome-templ   Update templates"
	@echo "  make dome-reboot  Rebuild templates from scratch"
	@echo "  make dome-clean   Remove dome temporary files"
	@echo "  make dome-plugins Package plugins for distribution"
	@echo
	@echo "[Dome] Development Variables:"
	@echo "  Dome framework  DOME = '$(DOME)'"
	@echo "  Arguments (dev) DOME_ARGS = '$(DOME_ARGS)'"
	@echo "  Export modules  DOME_EXPORTS = '$(DOME_EXPORTS)'"
	@echo "  Plugin modules  DOME_PLUGINS = '$(DOME_PLUGINS)'"
	@echo "  Local command   DOME_APP_CLI = '$(DOME_APP_CLI)'"
	@echo
	@echo "[Dome] Documentation Variables:"
	@echo "  Application     APP          = '$(APP)'"
	@echo "  Copyright       COPYRIGHT    = '$(COPYRIGHT)'"
	@echo "  Dome framework  DOME_DOC     = '$(DOME_DOC)'"
	@echo "  App. framework  DOME_APP_DOC = '$(DOME_APP_DOC)'"
	@echo "  App. Sources    DOME_APP_SRC = '$(DOME_APP_SRC)'"
	@echo

# --------------------------------------------------------------------------
# ---  Application Cleaning
# --------------------------------------------------------------------------

.PHONY: dome-clean

dome-clean:
	@echo "[Dome] remove temporary files"
	@rm -fr dist .dome-*.stamp

# --------------------------------------------------------------------------
# ---  Development Packages Init & Installation
# --------------------------------------------------------------------------

.PHONY: dome-pkg

include $(DOME)/template/makefile.packages

DOME_MK_BIN=$(PWD)/node_modules/.bin
DOME_MK_PKG= \
	package.json node_modules \
	$(DOME)/template/makefile.packages \
	$(DOME)/template/package.sh

node_modules:
	mkdir $@

dome-pkg: .dome-pkg.stamp
.dome-pkg.stamp: $(DOME_MK_PKG)
	@echo "[Dome] ----------------------------------------------------------------"
	@echo "[Dome] installing development packages"
	@echo "[Dome] ----------------------------------------------------------------"
	@$(DOME)/template/package.sh --dev $(DOME_DEV_PACKAGES)
	@echo "[Dome] ----------------------------------------------------------------"
	@echo "[Dome] installing application packages"
	@echo "[Dome] ----------------------------------------------------------------"
	@$(DOME)/template/package.sh --app $(DOME_APP_PACKAGES)
	@echo "[Dome] ----------------------------------------------------------------"
	@echo "[Dome] building application dependencies"
	@echo "[Dome] ----------------------------------------------------------------"
	yarn install
	yarn run electron-builder install-app-deps
	@touch $@

package.json:
	yarn init

# --------------------------------------------------------------------------
# ---  Application Templating
# --------------------------------------------------------------------------

.PHONY: dome-templ dome-reboot

DOME_MK_TEMPLATES= \
	.gitignore \
	.babelrc \
	webpack.main.js \
	webpack.plugin.js \
	webpack.renderer.js \
	electron-webpack.json \
	src/main/index.js \
	src/renderer/index.js

dome-templ: $(DOME_MK_TEMPLATES)
dome-reboot:
	echo "[Dome] Backup templates"
	@for f in $(DOME_MK_TEMPLATES) ; do mv -fv $$f $$f.backup ; done
	$(MAKE) dome-templ dome-pkg

# Templated files

ifeq ("$(DOME)",".")
.gitignore:
	@cp -f $(DOME)/template/git-ignore $@
else
.gitignore: $(DOME)/template/update.sh $(DOME)/template/git-ignore
	@((tail -r $(DOME)/template/git-ignore | tail -n +3 | tail -r) || head -n -3 $(DOME)/template/git-ignore)  > $(DOME)/template/git-ignore.local
	@echo "/$(DOME)" >> $(DOME)/template/git-ignore.local
	@tail -2 $(DOME)/template/git-ignore >> $(DOME)/template/git-ignore.local
	@$^.local $@
	@rm -f $(DOME)/template/git-ignore.local
endif

.babelrc: $(DOME)/template/update.sh $(DOME)/template/babelrc.json
	@$^ $@

webpack.main.js: $(DOME)/template/update.sh $(DOME)/template/webpack.main.js
	@$^ $@

webpack.renderer.js: $(DOME)/template/update.sh $(DOME)/template/webpack.renderer.js
	@$^ $@

webpack.plugin.js: $(DOME)/template/update.sh $(DOME)/template/webpack.plugin.js
	@$^ $@

electron-webpack.json: $(DOME)/template/update.sh $(DOME)/template/electron-webpack.json
	@$^ $@

src/renderer/index.js: $(DOME)/template/update.sh $(DOME)/template/renderer.js
	@$^ $@

src/main/index.js: $(DOME)/template/update.sh $(DOME)/template/main.js
	@cp $(DOME)/template/main.js       $(DOME)/template/main.js.local
	@echo "Dome.setName('$(APP)');" >> $(DOME)/template/main.js.local
	@echo "Dome.start();"           >> $(DOME)/template/main.js.local
	@$^.local $@
	@rm -f $(DOME)/template/main.js.local

# --------------------------------------------------------------------------
# ---  Custom Entry Points
# --------------------------------------------------------------------------

ifndef DOME_CUSTOM_ENTRIES

dome-templ: src/renderer/Application.js
src/renderer/Application.js:
	@echo "[Dome] creating $@ from template"
	@mkdir -p src/renderer
	@cp -f $(DOME)/template/Application.js $@

dome-templ: src/renderer/Preferences.js
src/renderer/Preferences.js:
	@echo "[Dome] creating $@ from template"
	@mkdir -p src/renderer
	@cp -f $(DOME)/template/Preferences.js $@

endif

# --------------------------------------------------------------------------
# ---  Exported API for Plugins
# --------------------------------------------------------------------------

.PHONY: dome-export-dev dome-export-app

DOME_MK_EXPORTS_JS=$(DOME)/src/misc/exports.js

# --------------------------------------------------------------------------

dome-export-dev:
	@rm -f $(DOME_MK_EXPORTS_JS)
	@echo "// Static Plugins Loader" > $(DOME_MK_EXPORTS_JS)
	@for m in $(DOME_EXPORTS) ;\
	 do \
		echo "[Dome] installing '$$m'" ;\
		echo "import '$$m';" \
		>> $(DOME_MK_EXPORTS_JS) ;\
	 done
	@for m in $(DOME_PLUGINS) ;\
	 do \
		echo "[Dome] loading plugin $$m" ;\
		echo "import '@plugins/$$m';" >> $(DOME_MK_EXPORTS_JS) ;\
	 done
	@chmod a-w $(DOME_MK_EXPORTS_JS)

# --------------------------------------------------------------------------

dome-export-app:
	@rm -f $(DOME_MK_EXPORTS_JS)
	@echo "// Static Loader (Generated by Dome)" > $(DOME_MK_EXPORTS_JS)
	@echo "import { register } from 'dome/misc/plugins' ;" >> $(DOME_MK_EXPORTS_JS) ;
	@echo "[Dome] export 'dome'" ;
	@$(DOME)/template/export.sh $(DOME) >> $(DOME_MK_EXPORTS_JS)
	@for m in $(DOME_EXPORTS) ;\
	 do \
		echo "[Dome] export '$$m'" ;\
		echo "{ let m = require('$$m'); register('$$m',m); }" \
		>> $(DOME_MK_EXPORTS_JS) ;\
	 done
	@for m in $(DOME_PLUGINS) ;\
	 do \
		echo "[Dome] install '@plugins/$$m'" ;\
		echo "{ let m = require('@plugins/$$m'); register('@plugins/$$m',m); }" \
		>> $(DOME_MK_EXPORTS_JS) ;\
	 done
	@chmod a-w $(DOME_MK_EXPORTS_JS)

# --------------------------------------------------------------------------
# ---  Packaging Plugins
# --------------------------------------------------------------------------

.PHONY: dome-plugins dome-plugin-%

DOME_MK_PLUGINS_TARGET=$(addprefix dome-plugin-, $(DOME_PLUGINS))
DOME_MK_PLUGINS_SOURCE=$(addprefix src/plugins/, $(DOME_PLUGINS))
DOME_MK_PLUGINS_CONFIG=$(addsuffix /package.json, $(DOME_MK_PLUGINS_SOURCE))

dome-plugins: $(DOME_MK_PLUGINS_CONFIG) $(DOME_MK_PLUGINS_TARGET)

dome-plugin-%: src/plugins/%/package.json webpack.plugin.js
	@echo "[Dome] building plugin '$*'"
	@rm -fr dist/plugins/$*
	@mkdir -p dist/plugins/$*
	@node $(DOME)/template/packplugin.js '$*'
	DOME=$(DOME) DOME_PLUGIN='$*' yarn run webpack -p --config webpack.plugin.js
	@echo "[Dome] plugin packaged in ./dist/plugins/$*"

src/plugins/%/package.json:
	@echo "[Dome] creating package.json for plugin '$*'"
	@echo '{' > $@
	@echo '  "name": "$*",' >> $@
	@echo '  "version": "0.1",' >> $@
	@echo '  "license": "UNLICENSED"' >> $@
	@echo '}' >> $@

# --------------------------------------------------------------------------
# ---  Application Development
# --------------------------------------------------------------------------

DOME_MK_CLIDIR=$(dir $(DOME_APP_CLI))

.PHONY: dome-dev

dome-dev: dome-pkg dome-templ dome-export-dev
	@echo "[Dome] linking $(DOME_APP_CLI)"
	@mkdir -p $(DOME_MK_CLIDIR)
	@rm -f $(DOME_APP_CLI)
	@echo "#!/bin/sh" >> $(DOME_APP_CLI)
	@echo "export DOME='$(DOME)'" >> $(DOME_APP_CLI)
	@echo "export DOME_ENV='dev'" >> $(DOME_APP_CLI)
	@echo 'exec $(DOME_MK_BIN)/electron-webpack dev "$$@"' >> $(DOME_APP_CLI)
	@chmod 555 $(DOME_APP_CLI)
	@echo "[Dome] running application (development)"
	@$(DOME_APP_CLI) $(DOME_ARGS)

# --------------------------------------------------------------------------
# ---  Application Building
# --------------------------------------------------------------------------

.PHONY: dome-app

dome-app: dome-pkg dome-templ dome-export-app
	@echo "[Dome] compiling application (production)"
	DOME=$(DOME) DOME_ENV='app' yarn run electron-webpack app
	@echo "[Dome] linking $(DOME_APP_CLI)"
	@mkdir -p $(DOME_MK_CLIDIR)
	@rm -f $(DOME_APP_CLI)
	@echo "#!/bin/sh" >> $(DOME_APP_CLI)
	@echo "export DOME_LOCAL=true" >> $(DOME_APP_CLI)
	@echo 'exec $(DOME_MK_BIN)/electron $(PWD)/dist/main/main.js "$$@"' >> $(DOME_APP_CLI)
	@chmod 555 $(DOME_APP_CLI)

# --------------------------------------------------------------------------
# ---  Application Packaging
# --------------------------------------------------------------------------

.PHONY: dome-dist

dome-dist: dome-app
	@echo "[Dome] packaging application (production)"
	DOME=$(DOME) yarn run electron-builder --dir -c.compression=store -c.mac.identity=null
	@echo "[Dome] application packaged in ./dist"

# --------------------------------------------------------------------------
# ---  Application JSdoc
# --------------------------------------------------------------------------

DOME_MK_API_DOC=$(PWD)/$(DOME_APP_DOC)
DOME_MK_API_SRC=$(PWD)/$(DOME_APP_SRC) $(addprefix $(PWD)/src/plugins/, $(DOME_PLUGINS))

dome-api: $(DOME_MK_BIN)/jsdoc
	@echo "[Dome] generating $(APP) documentation"
	@mkdir -p $(DOME_APP_DOC)
	@rm -f $(DOME_APP_DOC)/*.html
	@rm -f $(DOME_APP_DOC)/*.png
	@rm -f $(DOME_APP_DOC)/*.css
	@rm -fr $(DOME_APP_DOC)/fonts
	@rm -fr $(DOME_APP_DOC)/styles
	@(cd $(DOME) && DOME='.' DOME_PWD=$(PWD) APP=$(APP) COPYRIGHT="$(COPYRIGHT)" \
	  $(DOME_MK_BIN)/jsdoc -c ./doc/app.json $(DOME_MK_API_SRC) -d $(DOME_MK_API_DOC))
	@echo "[Dome]   $(DOME_APP_DOC)/index.html"

# --------------------------------------------------------------------------
# --- Icon gallery
# --------------------------------------------------------------------------

DOME_MK_ICON_MAKE=$(DOME)/doc/icons.js
DOME_MK_ICON_DATA=$(DOME)/src/renderer/controls/icons.json
DOME_MK_ICON_HTML=$(DOME)/doc/template/gallery-icons.html

$(DOME_MK_ICON_HTML): $(DOME_MK_ICON_MAKE) $(DOME_MK_ICON_DATA)
	@echo "[Dome] generating icons gallery"
	@node $(DOME_MK_ICON_MAKE) $(DOME_MK_ICON_DATA) > $(DOME_MK_ICON_HTML)

# --------------------------------------------------------------------------
# ---  Dome Documentation
# --------------------------------------------------------------------------

DOME_MK_DOC_OUT=$(addprefix $(PWD)/, $(DOME_DOC))

dome-doc: $(DOME_MK_BIN)/jsdoc $(DOME_MK_ICON_HTML)
	@echo "[Dome] generating Dome documentation"
	@mkdir -p $(DOME_DOC)
	@rm -f $(DOME_DOC)/*.html
	@rm -f $(DOME_DOC)/*.png
	@rm -f $(DOME_DOC)/*.css
	@rm -fr $(DOME_DOC)/fonts
	@rm -fr $(DOME_DOC)/styles
	@(cd $(DOME) && DOME="." DOME_PWD=$(PWD) COPYRIGHT='CEA Tech' \
	  $(DOME_MK_BIN)/jsdoc -c ./doc/config.json -d $(DOME_MK_DOC_OUT))
	@cp -f $(DOME)/doc/gallery.css $(DOME_DOC)/styles/
	@cp -f $(DOME)/doc/tutorials/*.png $(DOME_DOC)/
	@cat \
		$(DOME)/doc/template/gallery-head.html \
		$(DOME)/doc/template/gallery-icons.html \
		$(DOME)/doc/template/gallery-tail.html \
		> $(DOME_DOC)/gallery-icons.html
	@echo "[Dome]   $(DOME_DOC)/index.html"

# --- Doc binaries ---------------------------------------------------------

$(DOME_MK_BIN)/jsdoc:
	@echo "[Dome] installing jsdoc"
	@yarn add -D jsdoc

# --------------------------------------------------------------------------
