open Logic_typing
open Cil_types

let load_theory = function
  | { pred_content = Papp (_, [], [ { term_node = TConst(LStr _name) } ] ) } ->
    raise Not_found
  | _ -> assert false

let typing ~typing_context ~loc lexprs =
  ignore loc ;
  let type_predicate =
    typing_context.type_predicate typing_context (Lenv.empty ())
  in
  let predicates = List.map type_predicate lexprs in
  List.iter load_theory predicates ;
  Ext_preds predicates


let () =
  Logic_typing.register_global_extension "why3" false typing

let main () =
  try
    Kernel.feedback
      "Checking handler of exception occurring in extension typing";
    Ast.compute (); Kernel.fatal "Extension typing should have failed"
  with Not_found -> Kernel.feedback "Extension typing failed as expected"

let () = Kernel.TypeCheck.set false

let () = Db.Main.extend main
