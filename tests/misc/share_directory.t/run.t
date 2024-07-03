  $ dune build --root . @install

Basic case
  $ dune exec -- frama-c
  [kernel] IS_SET false
  [dirs] path (dir)
  [dirs] Found: _build/install/default/share/frama-c/share/dirs/path
  [dirs] Found: _build/install/default/share/frama-c/share/dirs/path
  [dirs] path/file.txt (file)
  [dirs] Found: _build/install/default/share/frama-c/share/dirs/path/file.txt
  [dirs] Found: _build/install/default/share/frama-c/share/dirs/path/file.txt
  [dirs] foo (dir)
  [dirs] User Error: Could not find directory foo in Frama-C/directories share
  [dirs] Found: _build/install/default/share/frama-c/share/dirs/foo
  [dirs] foo.txt (file)
  [dirs] User Error: Could not find file foo.txt in Frama-C/directories share
  [dirs] Found: _build/install/default/share/frama-c/share/dirs/foo.txt
  [dirs] path (file)
  [dirs] User Error: _build/install/default/share/frama-c/share/dirs/path is expected to be a file
  [dirs] User Error: _build/install/default/share/frama-c/share/dirs/path is expected to be a file
  [dirs] path/file.txt
  [dirs] User Error: _build/install/default/share/frama-c/share/dirs/path/file.txt is expected to be a directory
  [dirs] User Error: _build/install/default/share/frama-c/share/dirs/path/file.txt is expected to be a directory

With option
  $ cp -r share copied
  $ dune exec -- frama-c -dirs-share copied
  [kernel] IS_SET true
  [dirs] path (dir)
  [dirs] Found: copied/path
  [dirs] Found: copied/path
  [dirs] path/file.txt (file)
  [dirs] Found: copied/path/file.txt
  [dirs] Found: copied/path/file.txt
  [dirs] foo (dir)
  [dirs] User Error: Could not find directory foo in Frama-C/directories share
  [dirs] Found: copied/foo
  [dirs] foo.txt (file)
  [dirs] User Error: Could not find file foo.txt in Frama-C/directories share
  [dirs] Found: copied/foo.txt
  [dirs] path (file)
  [dirs] User Error: copied/path is expected to be a file
  [dirs] User Error: copied/path is expected to be a file
  [dirs] path/file.txt
  [dirs] User Error: copied/path/file.txt is expected to be a directory
  [dirs] User Error: copied/path/file.txt is expected to be a directory
