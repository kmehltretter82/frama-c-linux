FRAMAC=../../../../bin/frama-c
MTSHARE=../../../../plugins/eva/share/mthread

TARGETS = \
  ccfg.log \
  philo.noslevel.log \
	philo.slevel5.log \
	philo.mtverbose2.log \
	init.log \

CFG_TARGETS = \
  ccfg.dot \

PDF_CFG_TARGETS = $(CFG_TARGETS:.dot=.pdf)


.SECONDEXPANSION:
.PHONY: all clean

all: $(TARGETS) $(CFG_TARGETS) $(PDF_CFG_TARGETS)
clean:
	$(RM) *.log
	$(RM) *.dot
	$(RM) *.pdf
	$(RM) -r html_summary

MT_QUEUE = ${MTSHARE}/mthread_queue.c

MT_COMMON_FLAGS = \
  -eva \
  -mthread \
	-mt-threads-lib pthreads \
	-eva-verbose 0 \
	-add-symbolic-path=${MTSHARE}:MTSHARE \


%.log: SOURCE = $(word 1,$(subst ., ,$*)).c
$(TARGETS) : %.log: $$(SOURCE) $(FRAMAC) $(MAKEFILE_LIST)
	$(FRAMAC) \
		$(MT_COMMON_FLAGS) \
		$(FCFLAGS) \
		$< > $*.log

%.dot: SOURCE = $(word 1,$(subst ., ,$*)).log
$(CFG_TARGETS) : %.dot: $$(SOURCE) $(MAKEFILE_LIST)
	cp html_summary/_main_.dot $*.dot

%.pdf: SOURCE = $(word 1,$(subst ., ,$*)).dot
$(PDF_CFG_TARGETS) : %.pdf: $$(SOURCE) $(MAKEFILE_LIST)
	dot -Tpdf $< -o $@

ccfg.log: FCFLAGS += -eva-slevel 15 -mt-extract html -mt-keep-dot-files
philo.noslevel.log: FCFLAGS += ${MT_QUEUE}
philo.slevel5.log: FCFLAGS += ${MT_QUEUE} -eva-slevel 5
philo.mtverbose2.log: FCFLAGS += ${MT_QUEUE} -eva-slevel 5 -mt-verbose 2
init.log: FCFLAGS += -eva-slevel 3
