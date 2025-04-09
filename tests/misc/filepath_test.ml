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
  Kernel.feedback "relativize(.): %s"
    (Filepath.relativize ".");
  Kernel.feedback "relativize(./tests/..): %s"
    (Filepath.relativize "./tests/..");
  Kernel.feedback "relativize(/a/bc/d,base_name:/a/b/): %s"
    (Filepath.relativize ~base_name:"/a/b/" "/a/bc/d");
  Filepath.add_symbolic_dir "SYMB" (Filepath.of_string "/tmp/symb/");
  Kernel.feedback "pretty with symbolic path: %a"
    Filepath.pretty (Filepath.of_string "/tmp/symb/file.c")
