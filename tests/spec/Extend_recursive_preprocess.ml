open Logic_ptree
open Logic_const

let validate call =
  assert (not (String.equal "must_replace" call)) ;
  match String.split_on_char '_' call with
  | [ lkind ; lok ] -> String.equal "gl_fooo" lkind && String.equal lok "ok"
  | _ -> false

let ext_typing_fooo _typing_context _loc l =
  let type_lexpr = function
    | { lexpr_node = PLapp(s, [], [ _ ]) } when validate s -> ptrue
    | _ -> pfalse
  in
  Cil_types.Ext_preds (List.map type_lexpr l)

let ext_typing_block typing_context loc_here node =
  match node.extended_node with
  | Ext_lexpr (name,data)  ->
    let status,kind = Logic_typing.get_typer name typing_context node.extended_loc data in
    Logic_const.new_acsl_extension name loc_here status kind
  | Ext_extension (name, id, data) ->
    let status,kind = Logic_typing.get_typer_block name typing_context node.extended_loc (id,data) in
    Logic_const.new_acsl_extension name loc_here status kind

let  ext_typing_foo typing_context loc (s,d) =
  let block = List.map (ext_typing_block typing_context loc) d in
  Cil_types.Ext_annot (s,block)

let preprocess_fooo_ptree_element = function
  | { lexpr_node = PLapp("must_replace", [], [ v ]) } as x ->
    { x with lexpr_node = PLapp("gl_foo" ^ "_ok", [], [ v ]) }
  | x -> x

let preprocess_fooo_ptree = List.map preprocess_fooo_ptree_element

let preprocess_foo_ptree (id,data) =(id ^ "_ok",data)

let () =
  Acsl_extension.register_global
    "gl_fooo" ~preprocessor:preprocess_fooo_ptree ext_typing_fooo false ;
  Acsl_extension.register_global_block
    "gl_foo" ~preprocessor:preprocess_foo_ptree ext_typing_foo false
