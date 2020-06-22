open Cil_types

let e1 = Emitter.(create "emitter1" [ Code_annot ] [] [])
let e2 = Emitter.(create "emitter2" [ Code_annot ] [] [])

let add_assigns e kf stmt v =
  let lv = Cil.cvar_to_lvar v in
  let term_v  = Logic_const.tvar lv in
  let named_term_v =
    { term_v with
      term_name = ("added_by_"^(Emitter.get_name e))::term_v.term_name }
  in
  let id_v = Logic_const.new_identified_term named_term_v  in
  Annotations.add_code_annot e ~kf stmt
    (Logic_const.new_code_annotation
       (AAssigns ([], Writes [id_v, FromAny])));
  Filecheck.check_ast ("after insertion of loop assigns " ^ v.vname)

let add_allocates e kf stmt v =
  let lv = Cil.cvar_to_lvar v in
  let term_v = Logic_const.tvar lv in
  let named_term_v =
    { term_v with
      term_name = ("added_by_"^(Emitter.get_name e))::term_v.term_name }
  in
  let id_v = Logic_const.new_identified_term named_term_v in
  Annotations.add_code_annot e ~kf stmt
    (Logic_const.new_code_annotation
       (AAllocation([],FreeAlloc ([],[id_v]))));
  Filecheck.check_ast ("after insertion of loop allocates " ^ v.vname )

let check_only_one f =
  let seen = ref false in
  fun _ a ->
    if f a then begin
      assert (not !seen);
      seen := true
    end

let filter_category f _ a acc = if f a then a :: acc else acc

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
  let l = Cil.makeLocalVar def ~insert:true "l" Cil.intType in
  let p = Cil.makeLocalVar def ~insert:true "p" Cil.intPtrType in
  let q = Cil.makeLocalVar def ~insert:true "q" Cil.intPtrType in
  add_assigns e1 kf s j;
  add_assigns e2 kf s k;
  add_assigns e1 kf s l;
  add_allocates e1 kf s p;
  add_allocates e2 kf s q;
  Annotations.iter_code_annot (check_only_one Logic_utils.is_assigns) s;
  Annotations.iter_code_annot (check_only_one Logic_utils.is_allocation) s;
  let lassigns =
    Annotations.fold_code_annot (filter_category Logic_utils.is_assigns) s []
  in
  assert (List.length lassigns = 1);
  let lalloc =
    Annotations.fold_code_annot (filter_category Logic_utils.is_allocation) s []
  in
  assert (List.length lalloc = 1);
  ignore
    (Property_status.get
       (Property.ip_of_code_annot_single kf s (List.hd lassigns)));
  ignore
    (Property_status.get
       (Property.ip_of_code_annot_single kf s (List.hd lalloc)));
  File.pretty_ast ()

let () = Db.Main.extend main
