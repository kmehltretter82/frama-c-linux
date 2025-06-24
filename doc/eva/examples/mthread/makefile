FRAMAC=../../../../bin/frama-c
MTSHARE=../../../../src/plugins/eva/share/mthread

TARGETS = \
  ccfg.log \
  philo.noslevel.log \
	philo.slevel5.log \
	philo.mtverbose2.log \
	init.log \

CFG_TARGETS = \
  ccfg.pdf \


.SECONDEXPANSION:
.PHONY: all clean

all: $(TARGETS) $(CFG_TARGETS)
clean:
	$(RM) *.log
	$(RM) *.pdf
	$(RM) -r html_summary

MT_PTHREAD = ${MTSHARE}/mthread_pthread.c
MT_QUEUE = ${MTSHARE}/mthread_queue.c

MT_COMMON_FLAGS = \
  -mthread \
	-eva-domains mthread \
  -cpp-extra-args="-I${MTSHARE}" \
	-eva-verbose 0 \
	-add-symbolic-path=${MTSHARE}:MTSHARE \
	${MT_PTHREAD} \


%.log: SOURCE = $(word 1,$(subst ., ,$*)).c
$(TARGETS) : %.log: $$(SOURCE) $(FRAMAC) $(MAKEFILE_LIST)
	$(FRAMAC) \
		$(MT_COMMON_FLAGS) \
		$(FCFLAGS) \
		$< > $*.log

%.pdf: SOURCE = $(word 1,$(subst ., ,$*)).log
$(CFG_TARGETS) : %.pdf: $$(SOURCE) $(MAKEFILE_LIST)
	magick html_summary/'<main>.svg' $*.pdf

ccfg.log: FCFLAGS += -eva-slevel 15 -mt-extract html
philo.noslevel.log: FCFLAGS += ${MT_QUEUE}
philo.slevel5.log: FCFLAGS += ${MT_QUEUE} -eva-slevel 5
philo.mtverbose2.log: FCFLAGS += ${MT_QUEUE} -eva-slevel 5 -mt-verbose 2
init.log: FCFLAGS += -eva-slevel 3
