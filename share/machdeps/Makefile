update-all: machdep_*.yaml

machdep_avr_16.yaml \
machdep_gcc_x86_32.yaml \
machdep_gcc_x86_64.yaml \
machdep_ppc_32.yaml : \
%.yaml: machdep-schema.yaml make_machdep/make_machdep.py
	@./make_machdep/make_machdep.py -i --from-file $@ --check

machdep_x86_16.yaml machdep_x86_32.yaml machdep_x86_64.yaml: \
machdep_%.yaml: machdep_gcc_%.yaml Makefile
	@sed -e 's/sizeof_fun: .*/sizeof_fun: -1/' \
             -e 's/sizeof_void: .*/sizeof_void: -1/' \
             -e 's/alignof_fun: .*/alignof_fun: -1/' \
             -e 's/compiler: .*/compiler: generic/' \
             $< > $@

machdep_gcc_x86_16.yaml machdep_msvc_x86_64.yaml: %.yaml: machdep-schema.yaml
	@echo "$@ is newer than $< and must be updated manually"
	@exit 1
