open Cil_types

(* Note: this test must not include files with function definitions (.c), only
   headers with declarations. Otherwise, the reported locations for the
   functions will be the .c files, and not the .h where assigns are missing.
*)

let is_known_variadic env kf =
  let vi = Kernel_function.get_vi kf in
  match Classify.classify env vi with
  | Some _ -> true
  | None -> false

let run () =
  let file = Ast.get () in
  let env = Environment.from_file file in
  let check_assigns kf acc =
    let kf_name = Kernel_function.get_name kf in
    if kf_name = "main" ||
       is_known_variadic env kf
    then (* skip *) acc
    else
      let spec = Annotations.funspec kf in
      let default = List.find_opt (fun b ->
          b.b_name = Cil.default_behavior_name
        ) spec.spec_behavior
      in
      let loc = Kernel_function.get_location kf in
      match default with
      | None -> (kf_name, loc) :: acc
      | Some default ->
        if default.b_assigns = WritesAny then
          (kf_name, loc) :: acc
        else acc
  in
  let todo = Globals.Functions.fold check_assigns [] in
  if todo = [] then
    Kernel.feedback
      "All non-variadic functions in Frama-C's libc headers have assigns!@."
  else begin
    Kernel.warning "Missing assigns / default behavior in %d function(s):@."
      (List.length todo);
    List.iter (fun (name, loc) ->
        Format.printf "  %s (%a)@." name Printer.pp_location loc
      ) todo
  end

let () = Boot.Main.extend run
