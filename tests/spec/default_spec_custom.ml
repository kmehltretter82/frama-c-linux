open Cil_types

let gen_exits _ _ =
  [ Exits, Logic_const.(new_predicate pfalse) ]


let gen_assigns kf _ =
  if Kernel_function.has_definition kf then
    WritesAny
  else Writes (Infer_annotations.assigns_from_prototype kf)

let gen_requires _ _ = [ Logic_const.(new_predicate pfalse) ]

let gen_allocates kf _ =
  if Kernel_function.has_definition kf
  then FreeAlloc([],[])
  else FreeAllocAny

let gen_terminates kf _ =
  if Kernel_function.has_definition kf then
    None
  else Some(Logic_const.(new_predicate pfalse))

let status_exits = Property_status.Dont_know
let status_assigns = Property_status.True
let status_allocates = Property_status.Dont_know
let status_terminates = Property_status.Dont_know

let populate () =
  Format.printf "Registering an empty spec generation mode@.";
  Populate_spec.register "emptymode";
  Format.printf "Registering a new spec generation mode@.";
  Populate_spec.register
    ~gen_exits ~status_exits
    ~gen_assigns ~status_assigns
    ~gen_requires
    ~gen_allocates ~status_allocates
    ~gen_terminates ~status_terminates
    "mymode"


  let () = Cmdline.run_after_configuring_stage populate
