ifndef FRAMAC_SHARE
  FRAMAC_SHARE:=$(shell frama-c -print-share-path)
endif

Report_markdown_VERSION:=0.1~alpha

PLUGIN_NAME:=Report_markdown
PLUGIN_GENERATED:=mdr_version.ml
PLUGIN_CMO:=\
  markdown sarif mdr_version mdr_params parse_remarks \
  eva_coverage md_gen sarif_gen mdr_register
PLUGIN_NO_TEST:=true
PLUGIN_REQUIRES:=ppx_deriving ppx_deriving_yojson yojson
PLUGIN_VERSION:=$(Report_markdown_VERSION)
PLUGIN_DISTRIB_EXTERNAL:=share/acsl.xml

include $(FRAMAC_SHARE)/Makefile.dynamic

$(Report_markdown_DIR)/mdr_version.ml: $(Report_markdown_DIR)/Makefile
	$(PRINT_MAKING) $@
	$(RM) $@
	$(ECHO) "let version = \"$(Report_markdown_VERSION)\"" > $@
	$(CHMOD_RO) $@

$(Report_markdown_DIR)/Report_markdown.mli: \
  $(Report_markdown_DIR)/mdr_params.mli \
  $(Report_markdown_DIR)/markdown.mli \
  $(Report_markdown_DIR)/md_gen.mli \
  $(Report_markdown_DIR)/Makefile
	echo "module Mdr_params: sig" > $@
	cat mdr_params.mli >> $@
	echo "end" >> $@
	echo "module Markdown: sig" >> $@
	cat markdown.mli >> $@
	echo "end" >> $@
	echo "module Md_gen: sig" >> $@
	cat md_gen.mli >> $@
	echo "end" >> $@

install::
	$(PRINT_CP) $(FRAMAC_DATADIR)/Report_markdown
	$(MKDIR) $(FRAMAC_DATADIR)/Report_markdown
	$(CP) share/acsl.xml $(FRAMAC_DATADIR)/Report_markdown
