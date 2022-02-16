let ptest_file =
  try
    let session = Unix.getenv "FRAMAC_SESSION" in
    if session = Unix.getcwd () then fun dir file -> dir ^ file
    else fun _ file -> file
  with Not_found -> fun dir file -> dir ^ file


let foo () =
  if Project.get_name (Project.current ()) <> "prj" then begin
    let prj = Project.create "prj" in
    let () = Project.set_current prj in
    let f = Filepath.Normalized.of_string (ptest_file "" "big_local_array.i") in
    File.init_from_c_files [File.from_filename f]
  end

let () = Db.Main.extend foo
