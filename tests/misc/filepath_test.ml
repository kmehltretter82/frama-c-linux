let () =
  Kernel.feedback "normalize(/): %s"
    (Filepath.of_string "/" :> string );
  Kernel.feedback "normalize(/..): %s"
    (Filepath.of_string "/.." :> string );
  Kernel.feedback "normalize(/../../.): %s"
    (Filepath.of_string "/../../." :> string );
  (* when there are several '/', only the last one is removed *)
  Kernel.feedback "normalize(///): %s"
    (Filepath.of_string "///" :> string );
  Kernel.feedback "normalize(//tmp//): %s"
    (Filepath.of_string "//tmp//" :> string );
  Kernel.feedback "normalize(/../tmp/../..): %s"
    (Filepath.of_string "/../tmp/../.." :> string );
  Kernel.feedback "normalize(/tmp/inexistent_directory/..): %s"
    (Filepath.of_string "/tmp/inexistent_directory/.." :> string );
  Kernel.feedback "normalize(): %s"
    (Filepath.of_string "" :> string );
  Kernel.feedback "to_string_rel(.): %s"
    (Filepath.(to_string_rel (of_string ".")));
  Kernel.feedback "to_string_rel(./tests/..): %s"
    (Filepath.(to_string_rel (of_string "./tests/..")));
  Kernel.feedback "to_string_rel(/a/bc/d,base_name:/a/b/): %s"
    (Filepath.(to_string_rel ~base:(of_string "/a/b/") (of_string "/a/bc/d")));
  Filepath.add_symbolic_dir "SYMB" (Filepath.of_string "/tmp/symb/");
  Kernel.feedback "pretty with symbolic path: %a"
    Filepath.pretty (Filepath.of_string "/tmp/symb/file.c")
