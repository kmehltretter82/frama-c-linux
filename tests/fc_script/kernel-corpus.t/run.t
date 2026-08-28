  $ mkdir kernel build
  $ touch kernel/ok.c kernel/preprocess.c kernel/syntax.c kernel/builtin.c kernel/normalize.c kernel/static.c model.h
  $ cat > compile_commands.json <<EOF
  > [
  >   {"directory":"$PWD/build","file":"$PWD/kernel/ok.c","command":"cc -c $PWD/kernel/ok.c"},
  >   {"directory":"$PWD/build","file":"$PWD/kernel/preprocess.c","command":"cc -c $PWD/kernel/preprocess.c"},
  >   {"directory":"$PWD/build","file":"$PWD/kernel/syntax.c","command":"cc -c $PWD/kernel/syntax.c"},
  >   {"directory":"$PWD/build","file":"$PWD/kernel/builtin.c","command":"cc -c $PWD/kernel/builtin.c"},
  >   {"directory":"$PWD/build","file":"$PWD/kernel/normalize.c","command":"cc -c $PWD/kernel/normalize.c"},
  >   {"directory":"$PWD/build","file":"$PWD/kernel/static.c","command":"cc -c $PWD/kernel/static.c"}
  > ]
  > EOF
  $ kernel_commit=$(git -C kernel init -q && git -C kernel config user.email test@example.com && git -C kernel config user.name Test && git -C kernel add . && git -C kernel commit -qm initial && git -C kernel rev-parse HEAD)
  $ cat > corpus.json <<EOF
  > {"name":"test", "linux_commit":"$kernel_commit", "model_headers":["model.h"], "files":["ok.c","preprocess.c","syntax.c","builtin.c","normalize.c","static.c"]}
  > EOF
  $ cat > fake-frama-c <<'EOF'
  > #!/bin/bash
  > if [ "$1" = "-version" ]; then
  >   echo "fake-frama-c 1.0"
  >   exit 0
  > fi
  > case "${!#}" in
  >   */ok.c)
  >     echo '[metrics] Defined functions (2)'
  >     echo '  Sloc = 7'
  >     echo '  Function = 2'
  >     ;;
  >   */preprocess.c)
  >     echo '[kernel] User Error: failed to run: cc -E'
  >     exit 1
  >     ;;
  >   */syntax.c)
  >     echo '[kernel] syntax error:'
  >     echo 'unexpected token'
  >     exit 1
  >     ;;
  >   */builtin.c)
  >     echo '[kernel] User Error: Cannot resolve variable __builtin_example'
  >     exit 1
  >     ;;
  >   */normalize.c)
  >     echo '[kernel] User Error: normalization of lval failed'
  >     exit 1
  >     ;;
  >   */static.c)
  >     echo '[kernel] test.c:1: User Error: static assertion failed: nope'
  >     exit 1
  >     ;;
  > esac
  > EOF
  $ chmod +x fake-frama-c
  $ frama-c-script kernel-corpus -p compile_commands.json --kernel-root kernel --corpus corpus.json --frama-c ./fake-frama-c --jobs 2 --quiet -o results.json
  typed 1/6 (16.7%); typed=1, preprocessing=1, syntax=1, typing=1, normalization=1, missing-model=1
  report: $TESTCASE_ROOT/results.json
  $ python3 - <<'EOF'
  > import json
  > result = json.load(open("results.json"))
  > print(result["schema_version"])
  > print(result["frama_c"]["version"])
  > print([item["path"].rsplit("/", 1)[-1] for item in result["frama_c"]["model_headers"]])
  > print(any(arg.startswith("-cpp-extra-args=-include ") and arg.endswith("/model.h") for arg in result["results"][0]["frama_c_command"]))
  > summary = dict(result["summary"])
  > summary.pop("total_process_seconds")
  > print(summary)
  > print([(item["file"], item["stage"], item["failure_kind"]) for item in result["results"]])
  > print(result["results"][0]["metrics"])
  > EOF
  2
  fake-frama-c 1.0
  ['model.h']
  True
  {'attempted': 6, 'typed': 1, 'success_rate': 0.166667, 'by_stage': {'typed': 1, 'preprocessing': 1, 'syntax': 1, 'typing': 1, 'normalization': 1, 'missing-model': 1}, 'failures_by_kind': {'builtin:__builtin_example': 1, 'failed-static-assert': 1, 'normalization-failure': 1, 'preprocessor-command': 1, 'syntax-error': 1}}
  [('ok.c', 'typed', 'typed-ast'), ('preprocess.c', 'preprocessing', 'preprocessor-command'), ('syntax.c', 'syntax', 'syntax-error'), ('builtin.c', 'missing-model', 'builtin:__builtin_example'), ('normalize.c', 'normalization', 'normalization-failure'), ('static.c', 'typing', 'failed-static-assert')]
  {'defined_functions': 2, 'sloc': 7, 'functions': 2}
