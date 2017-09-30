FRAMAC_SHARE:=$(shell frama-c -print-share-path)

PLUGIN_NAME:=Report_markdown
PLUGIN_CMO:=markdown md_gen
PLUGIN_NO_TEST:=true

include $(FRAMAC_SHARE)/Makefile.dynamic

Report_markdown.mli: markdown.mli md_gen.mli
	echo "module Markdown: sig" > $@
	cat markdown.mli >> $@
	echo "end" >> $@
	echo "module Md_gen: sig" >> $@
	cat md_gen.mli >> $@
	echo "end" >> $@
