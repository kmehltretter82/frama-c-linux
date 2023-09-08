let run () =
  let open Populate_spec in
  let get_spec kf =
    let funspec = Annotations.funspec kf in
    populate_funspec ~do_body:true ~funspec kf [`Exits];
    populate_funspec ~do_body:true kf [`Assigns];
    populate_funspec ~do_body:true kf [`Requires];
    populate_funspec ~do_body:true kf [`Allocates];
    populate_funspec ~do_body:true kf [`Terminates];

    (* Should no nothing *)
    ignore(!Annotations.populate_spec_ref kf funspec);
    populate_funspec ~do_body:true kf
      [`Exits; `Assigns; `Requires; `Allocates; `Terminates]
  in
  Globals.Functions.iter get_spec
  [@@ warning "-3"]

let () = Db.Main.extend run
