.PHONY: run-tests clean-tests purge-tests tests

purge-tests:
	find tests -name dune | grep -e "oracle.*/\|result.*/" | xargs --no-run-if-empty rm

clean-tests: purge-tests
	rm -rf _build/default/ptests/tests

run-tests: purge-tests
	dune exec -- ../ptests/ptests.exe ./tests
	dune build @tests/ptests

tests: run-tests
