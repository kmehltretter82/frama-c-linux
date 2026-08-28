  $ mkdir -p kernel/drivers build override
  $ touch kernel/drivers/example.c harness.c override/example.c
  $ python3 - <<'EOF'
  > import json
  > from pathlib import Path
  > root = Path.cwd()
  > entry = {
  >   "directory": str(root / "build"),
  >   "file": str(root / "kernel/drivers/example.c"),
  >   "command": f"cc -DNAME='value with space' -c {root / 'kernel/drivers/example.c'}",
  > }
  > Path("compile_commands.json").write_text(json.dumps([entry]))
  > EOF
  $ frama-c-script kernel-harness -p compile_commands.json --source kernel/drivers/example.c --harness harness.c --source-override override/example.c -o mapped.json --quiet
  $ python3 - <<'EOF'
  > import json
  > entry = json.load(open("mapped.json"))[0]
  > args = entry["arguments"]
  > print(entry["file"].endswith("/harness.c"))
  > print("command" in entry)
  > print(args[0])
  > print(args[1].endswith("/override"))
  > print(args[2].endswith("/kernel/drivers"))
  > print("-DNAME=value with space" in args)
  > print(args[-1].endswith("/harness.c"))
  > EOF
  True
  False
  cc
  True
  True
  True
  True
