let run () =
  let open Populate_spec in
  let generate_spec kf =
    let funspec = Annotations.funspec kf in
    populate_funspec ~do_body:true kf [`Exits];
    (* Populates assigns using old deprecated API function. *)
    ignore(!Annotations.populate_spec_ref kf funspec);
    populate_funspec ~do_body:true kf [`Requires];
    populate_funspec ~do_body:true kf [`Allocates];
    populate_funspec ~do_body:true kf [`Terminates];

    (* Should no nothing *)
    populate_funspec ~do_body:true kf
      [`Exits; `Assigns; `Requires; `Allocates; `Terminates]
  in
  Globals.Functions.iter generate_spec
[@@ warning "-3"]

let () = Boot.Main.extend run
