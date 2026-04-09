let run () =
  List.iter (fun (pos1, pos2, fname) ->
      Format.printf "%a - %a -> %s@."
        Filepos.pp_with_col pos1
        Filepos.pp_with_col pos2
        fname
    ) (Cabs2cil.func_locs ())

let () = Boot.Main.extend run
