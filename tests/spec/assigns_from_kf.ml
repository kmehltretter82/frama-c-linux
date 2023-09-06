let run () =
  Globals.Functions.iter (fun kf ->
      Populate_spec.(populate_funspec kf [`Assigns]);
      ignore (Annotations.funspec kf)
    )

let () = Db.Main.extend run
