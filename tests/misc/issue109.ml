let ptest_file =
  try
    let session = Unix.getenv "FRAMAC_SESSION" in
    if session = Unix.getcwd () then fun dir file -> dir ^ file
    else fun _ file -> file
  with Not_found -> fun dir file -> dir ^ file

let main () =
  Eva.Analysis.compute ();
  Dynamic.Parameter.String.set "" "";
  Dynamic.Parameter.String.set "" (ptest_file "tests/misc/" "issue109.i");
  File.init_from_cmdline ();
  Eva.Analysis.compute ()

let main = Db.Main.extend main
