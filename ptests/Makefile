.PHONY: run-tests clean-tests purge-tests tests

purge-tests:
	find tests -name dune | grep -e "oracle.*/\|result.*/" | xargs --no-run-if-empty rm

clean-tests: purge-tests
	rm -rf _build/default/ptests/tests

TESTS= nothing cmd
# opts

run-tests: purge-tests
	for dir in $(TESTS) ; do \
	  dune exec -- ../ptests/ptests.exe ./tests/$$dir/tests ; \
	done
	dune build $(addprefix @tests/,$(addsuffix /tests/ptests,$(TESTS)))

tests: run-tests
