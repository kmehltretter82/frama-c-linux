open Cil_types

let fold t =
  match t.term_node with
  | TSizeOf _ | TSizeOfStr _ | TSizeOfE _ |  TAlignOf _ | TAlignOfE _
  | TUnOp _ | TBinOp _ ->
    let t' = Cil.constFoldTerm t in
    Format.printf "  %a folds to %a@." Cil_printer.pp_term t Cil_printer.pp_term t'
  | _ -> ()

class visitTerm prj = object(_)
  inherit Visitor.frama_c_copy prj

  method! vterm t =
    fold t;
    Cil.DoChildren

end

let test_terms () =
  let open Cil_builder.Exp in
  let loc = Cil_datatype.Location.unknown in
  let e1 = lognot ((of_int 21) + (of_int 21)) in
  let e2 = lognot ((of_int 21) - (of_int 21)) in
  let t1 = cil_term ~loc e1 in
  let t2 = cil_term ~loc e2 in
  Format.printf "Custom terms : @.";
  fold t1;
  fold t2

let startup () =
  test_terms ();
  Format.printf "File terms : @.";
  let prj = File.create_project_from_visitor "test_const_fold"
      (fun prj -> new visitTerm prj)
  in
  Project.set_current prj

let () = Boot.Main.extend startup
