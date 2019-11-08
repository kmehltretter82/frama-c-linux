open Logic_typing
open Cil_types

let load_theory = function
  | { pred_content = Papp (_, [], [ { term_node = TConst(LStr _name) } ] ) } ->
    let open Why3 in ignore (
      Theory.import_namespace Theory.empty_ns [_name]
    )
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
