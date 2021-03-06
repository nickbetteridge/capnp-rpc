.PHONY: all fuzz clean test

default: test build-fuzz

all:
	dune build @install test/test.bc test-lwt/test.bc test-bin/calc.exe test-mirage/test.bc
	rm -rf _build/_tests
	dune runtest --no-buffer -j 1

build-fuzz:
	dune build fuzz/fuzz.exe

fuzz: build-fuzz
	# TODO: remove -d
	afl-fuzz -d -i _build/in -o _build/out -- ./_build/default/fuzz/fuzz.exe --fuzz

clean:
	rm -rf _build

test:
	rm -rf _build/_tests
	dune build test/test.bc test-lwt/test.bc test-bin/calc.bc test-mirage/test.bc
	#./_build/default/test/test.bc test core -ev 36
	#./_build/default/test-lwt/test.bc test lwt -ev 3
	dune build @runtest --no-buffer -j 1
