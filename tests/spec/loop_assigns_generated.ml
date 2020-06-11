open Cil_types

let e1 = Emitter.(create "emitter1" [ Code_annot ] [] [])
let e2 = Emitter.(create "emitter2" [ Code_annot ] [] [])

let add_assigns e kf stmt v =
  let lv = Cil.cvar_to_lvar v in
  let term_v  = Logic_const.tvar lv in
  let named_term_v = { term_v with term_name = ("added_by_"^(Emitter.get_name e))::term_v.term_name } in
  let id_v = Logic_const.new_identified_term named_term_v  in
  Annotations.add_code_annot e ~kf stmt
    (Logic_const.new_code_annotation
       (AAssigns ([], Writes [id_v, FromAny])));
  Filecheck.check_ast ("after insertion of loop assigns " ^ v.vname)

let main () =
  Ast.compute();
  let kf = Globals.Functions.find_by_name "f" in
  let def = Kernel_function.get_definition kf in
  let s =
    List.find
      (fun s -> match s.skind with Loop _ -> true | _ -> false) def.sallstmts
  in
  let j = Cil.makeLocalVar def ~insert:true "j" Cil.intType in
  let k = Cil.makeLocalVar def ~insert:true "k" Cil.intType in
  add_assigns e1 kf s j;
  add_assigns e2 kf s k;
  File.pretty_ast ()

let () = Db.Main.extend main
