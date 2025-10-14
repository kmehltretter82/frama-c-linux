  $ frama-c -no-autoload-plugins -mopsa-db mopsa-db.json -mopsa-target libcool.a,libhot.a
  [kernel] Parsing a.c (with preprocessing)
  [kernel] Parsing b.c (with preprocessing)

  $ frama-c -no-autoload-plugins -mopsa-db mopsa-db.json -mopsa-target libcool.a,bar
  [kernel] Warning: option -cpp-extra-args-per-file: 'a.c' previously bound to '" -D 'FOO'"';
    now bound to '" -D 'BAR'"'.
  [kernel] Parsing a.c (with preprocessing)
  [kernel] Parsing b.c (with preprocessing)
