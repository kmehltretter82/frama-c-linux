open Cil_types

let gen_exits _ _ = [ ]
let status_exits = Property_status.Dont_know

let gen_assigns _ _ = WritesAny
let status_assigns = Property_status.Dont_know

let gen_requires _ _ = [ ]

let gen_allocates _ _ = FreeAllocAny
let status_allocates = Property_status.Dont_know

let gen_terminates _ _ = None
let status_terminates = Property_status.Dont_know

let run () =
  let get_spec kf =
    ignore(Annotations.funspec kf)
  in
  Globals.Functions.iter get_spec

let populate () =
  Format.printf "Registering an mode that does nothing@.";
  Populate_spec.register
    ~gen_exits ~status_exits
    ~gen_assigns ~status_assigns
    ~gen_requires
    ~gen_allocates ~status_allocates
    ~gen_terminates ~status_terminates
    "donothing"


let () = Cmdline.run_after_configuring_stage populate
