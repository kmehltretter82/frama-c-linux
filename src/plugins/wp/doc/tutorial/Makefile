# --------------------------------------------------------------------------
# ---  WP User & Reference Manual                                        ---
# --------------------------------------------------------------------------

.PHONY: all clean

all: tutorial.pdf

include ../MakeDoc

TEX= \
	tutorial.tex \
	tut_intro.tex \
	tut_function.tex \
	tut_maxmin.tex \
	tut_binary.tex \
	tut_rationale.tex \
	tut_mutating.tex \
	library.spec \
	equal/equal.tex \
	equal/equal.spec \
	equal/equal.impl \
	mismatch/mismatch.tex \
	mismatch/mismatch.spec \
	mismatch/mismatch.impl \
	mismatch/equal.c \
	find/find.tex \
	find/hasvalue.spec \
	find/find.spec \
	find/find.impl \
	findfirst/findfirst.tex \
	findfirst/hasvalueof.spec \
	findfirst/findfirst.spec \
	findfirst/findfirst.impl \
	adjacent/adjacent.tex \
	adjacent/neighbors.spec \
	adjacent/adjacent.spec \
	adjacent/adjacent.impl \
	count/count.tex \
	count/count.axioms \
	count/count.lemma \
	count/count.axioms \
	count/count.spec \
	count/count.impl \
	search/search.tex \
	search/hasrange.spec \
	search/search.spec \
	search/search.impl \
	compare/compare.tex \
	compare/less.spec \
	compare/greater.spec \
	maxelt/maxelt.tex \
	maxelt/maxelt.spec \
	maxelt/maxelt.impl \
	maxeltp/maxelt.tex \
	maxeltp/maximum.spec \
	maxeltp/maxelt.spec \
	maxeltp/maxelt.impl \
	maxseq/maxseq.tex \
	maxseq/maxseq.spec \
	maxseq/maxseq.impl \
	minelt/minelt.tex \
	minelt/minelt.spec \
	minelt/minelt.impl \
	binary/sorted.spec \
	binary/division.spec \
	lowerbound/lowerbound.tex \
	lowerbound/lowerbound.spec \
	lowerbound/lowerbound.impl \
	upperbound/upperbound.tex \
	upperbound/upperbound.spec \
	upperbound/upperbound.impl \
	binarysearch/binarysearch.tex \
	binarysearch/binarysearch.spec \
	binarysearch/binarysearch.impl \
	fill/fill.tex \
	fill/fill.spec \
	fill/fill.impl \
	swap/swap.tex \
	swap/swap.spec \
	swap/swap.impl \
	swapvalues/swapvalues.tex \
	swapvalues/swapvalues.spec \
	swapvalues/swapvalues.impl \
	swapranges/swapranges.tex \
	swapranges/swapranges.spec \
	swapranges/swapranges.impl \
	copy/copy.tex \
	copy/copy.spec \
	copy/copy.impl \
	reversecopy/reversecopy.tex \
	reversecopy/reversecopy.spec \
	reversecopy/reversecopy.impl \
	reversecopy/reverse.spec \
	reversecopy/reverse.impl \
	rotatecopy/rotatecopy.tex \
	rotatecopy/rotatecopy.spec \
	rotatecopy/rotatecopy.impl \
	replacecopy/replacecopy.tex \
	replacecopy/replacecopy.spec \
	replacecopy/replacecopy.impl \
	removecopy/removecopy.tex \
	removecopy/removecopy.spec \
	removecopy/removecopy.impl \
	removecopy/removecopy.axioms \
	removecopy/original.axioms \
	uniquecopy/uniquecopy.tex \
	uniquecopy/uniquecopy.spec \
	uniquecopy/uniquecopy.impl \
	uniquecopy/uniquecopy.axioms \
	uniquecopy/original.axioms \
	iota/iota.tex \
	iota/iota.spec \
	iota/iota.impl \

NONMUTATING= \
	equal equal_rte mismatch eqmismatch \
	find findfirst adjacent \
	count search

MAXMIN= compare maxelt maxeltp minelt maxseq
BINARY= lowerbound upperbound binarysearch
MUTATING= \
	fill swap

ORACLES= \
	$(addprefix tests/nonmutating/oracle/, $(addsuffix .res.oracle, $(NONMUTATING))) \
	$(addprefix tests/maxmin/oracle/, $(addsuffix .res.oracle, $(MAXMIN))) \
	$(addprefix tests/binary/oracle/, $(addsuffix .res.oracle, $(BINARY))) \
	$(addprefix tests/mutating/oracle/, $(addsuffix .res.oracle, $(MUTATING))) \

OLD= \
	swapvalues/swapvalues.log \
	swapvalues/swapvalues-withassert.log \
	swapranges/swapranges.log \
	copy/copy.log \
	reversecopy/reversecopy.log \
	reversecopy/reverse.log \
	rotatecopy/rotatecopy.log \
	replacecopy/replacecopy.log \
	removecopy/removecopy.log \
	uniquecopy/uniquecopy.log \
	iota/iota.log \

# --------------------------------------------------------------------------
# ---  General                                                           ---
# --------------------------------------------------------------------------

clean::
	@echo "Cleaning Tutorial"
	rm -f tutorial.pdf *.cb *.cb2 *.log *.out *.toc *.aux *.blg *.bbl *~

tutorial.pdf: $(FRAMAC_DOC) $(TEX) $(SOURCE) $(ORACLES)
	rubber -d tutorial

# --------------------------------------------------------------------------
# ---  Generated Logs via ptests                                         ---
# --------------------------------------------------------------------------

.PHONY: config tests kdiff3 update

tests: config
	ptests.opt -j 2

kdiff3: config
	ptests.opt -j 2 -diff kdiff3

update: config
	ptests.opt -update


config: tests/test_config tests/ptests_config

LIB_PATH=`frama-c -print-lib-path`
SHARE_PATH=`frama-c -print-share-path`

tests/test_config: tests/test_config.in
	rm -f $@
	@echo "SED $< ->  $@"
	sed "s|@LIB_PATH@|-add-path ${LIB_PATH}/plugins -add-path .|" $< > $@
	chmod -f a-w $@

tests/ptests_config: ptests_local_config.in
	rm -f $@
	@echo "SED $< ->  $@"
	sed "s|@LIB_PATH@|${LIB_PATH}|" $< \
	| sed "s|@SHARE_PATH@|${SHARE_PATH}|" > $@
	chmod -f a-w $@

# --------------------------------------------------------------------------
# ---  ZIP of Examples
# --------------------------------------------------------------------------

.PHONY: archive

archive:
	cd .. && (find tutorial -name "README" -or -name "*.spec" -or -name "*.impl" -or -name "*.h" -or -name "*.c" | \
        xargs tar zcf tutorial/tutorial.tgz)

# --------------------------------------------------------------------------
.PHONY: help

help:
	@echo "step 1: make tests   -> Runs tests"
	@echo "step 2: make update  -> Updates oracles (ptests -update)"
	@echo "step 3: make all     -> Build tutorial.pdf file from oracles"
	@echo "step 4: make archive -> Build tutorial.tgz archive file"
