open Cil_types

(* We start by defining all our generation function. Each function takes 2
   parameters:
   - the current kernel_function for which we want to generate specifications.
   - this kernel function specifications.

   And returns a new clause, which needs to match the type of clause we are
   currently generating (See Populate_spec.mli for more details.)
*)

(* Generate exits \false clauses. *)
let gen_exits _ _ =
  [ Exits, Logic_const.(new_predicate pfalse) ]

(* Generate assigns for prototypes. *)
let gen_assigns kf _ =
  if Kernel_function.has_definition kf then
    Writes []
  else Writes (Infer_assigns.from_prototype kf)

(* Generate requires \false clauses. *)
let gen_requires _ _ = [ Logic_const.(new_predicate pfalse) ]

(* Generate allocates \nothing clauses. *)
let gen_allocates _ _ =
  FreeAlloc([],[])

(* Generate terminates \false for prototypes. *)
let gen_terminates kf _ =
  if Kernel_function.has_definition kf then
    None
  else Some(Logic_const.(new_predicate pfalse))

(* Property status to be emitted for the generated clauses. *)
let status_exits = Property_status.Dont_know
let status_assigns = Property_status.True
let status_allocates = Property_status.Dont_know
let status_terminates = Property_status.Dont_know

(* Main loop, iter on all functions and generate their specification.
   If [do_body] is false by default, and is used to enable generation for
   function with bodies.
   We also give a list of clauses, which will be generated using the selected
   mode.
*)
let run () =
  let generate_spec kf =
    Populate_spec.populate_funspec ~do_body:true kf
      [`Exits; `Assigns; `Requires; `Allocates; `Terminates]
  in
  Globals.Functions.iter generate_spec

(* This function registers a new mode "mymode" which can be selected using
   command line options. All parameters are optionnals, and if left unspecified,
   Frama_C mode will be used to generate the corresponding clauses
   (emits a warning). Status are also optionnals, but omitting them will results
   in no emition (emits a warning).
*)
let create_mode () =
  Format.printf "Registering a new spec generation mode@.";
  Populate_spec.register
    ~gen_exits ~status_exits
    ~gen_assigns ~status_assigns
    ~gen_requires
    ~gen_allocates ~status_allocates
    ~gen_terminates ~status_terminates
    "mymode"

(* It is important to register the new mode in an early stage, before our
   main loop and first calls of Populate_spec.populate_funspec done inside
   frama-c. *)
let () = Cmdline.run_after_configuring_stage create_mode

let () = Boot.Main.extend run
