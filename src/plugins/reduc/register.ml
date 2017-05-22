module Options = Reduc_options

let command_line () =
  let varh = match Options.GenVars.get () with
    | "all" -> Collect.VarAll
    | _ -> Options.fatal "Not a valid variable heuristic" in
  let annoth = match Options.GenAnnot.get () with
    | "all" -> Collect.AnnotAll
    | "inout" -> Collect.AnnotInout
    | _ -> Options.fatal "Not a valid annotation heuristic"
  in
  varh, annoth

let main () =
  if (Options.Reduc.get ()) then begin
    let varh, annoth = command_line () in
    let env = Alarms.fold Collect.get_relevant (Collect.empty_env varh annoth) in
    Hyp.generate_hypotheses env;
    ()
  end

let () = Db.Main.extend main
