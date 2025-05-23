(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* Assertions emitted during the analysis *)

let emitter =
  Emitter.create
    "Eva"
    [ Emitter.Property_status; Emitter.Alarm ]
    ~correctness:Parameters.parameters_correctness
    ~tuning:Parameters.parameters_tuning

let get_slevel kf =
  try Parameters.SlevelFunction.find kf
  with Not_found -> Parameters.SemanticUnrollingLevel.get ()

let get_subdivision_option stmt =
  try
    let kf = Kernel_function.find_englobing_kf stmt in
    Parameters.LinearLevelFunction.find kf
  with Not_found -> Parameters.LinearLevel.get ()

let get_subdivision stmt =
  match Eva_annotations.get_subdivision_annot stmt with
  | [] -> get_subdivision_option stmt
  | [x] -> x
  | x :: _ ->
    Self.warning ~current:true ~once:true
      "Several subdivision annotations at the same statement; selecting %i\
       and ignoring the others." x;
    x

let pretty_actuals fmt actuals =
  let pp fmt (e,x) = Cvalue.V.pretty_typ (Some (e.Eva_ast.typ)) fmt x in
  Pretty_utils.pp_flowlist pp fmt actuals

module DegenerationPoints =
  Cil_state_builder.Stmt_hashtbl
    (Datatype.Bool)
    (struct
      let name = "Eva_utils.Degeneration"
      let size = 17
      let dependencies = [ Self.state ]
    end)

let is_interactive () = System_config.is_gui || Server.Main.is_active ()
let is_saved () = not (Kernel.SaveState.is_empty ())

let protect_only_once = ref true

let protect f ~cleanup =
  protect_only_once := true;
  let catch () = is_interactive () || is_saved () in
  let cleanup () =
    Self.feedback ~once:true "Clean up and save partial results.";
    try cleanup ()
    with e ->
      protect_only_once := false;
      raise e
  in
  try f ();
  with
  | Log.(AbortError _ | AbortFatal _ | FeatureRequest _) as e when catch () ->
    cleanup (); raise e
  | Sys.Break as e when catch () && !protect_only_once ->
    cleanup (); raise e
  | Self.Abort as e ->
    cleanup (); raise e

let register_new_var v typ =
  if Ast_types.is_fun typ then
    Globals.Functions.replace_by_declaration (Cil.empty_funspec()) v v.vdecl
  else
    Globals.Vars.add_decl v

let create_new_var name typ =
  let vi = Cil.makeGlobalVar ~source:false ~temp:false name typ in
  register_new_var vi typ;
  vi

let is_const_write_invalid typ = Ast_types.has_qualifier "const" typ

let find_return_var kf =
  match (Kernel_function.find_return kf).skind with
  | Return (Some ({enode = Lval ((Var vi, NoOffset))}), _) -> Some vi
  | _ | exception Kernel_function.No_Statement -> None

(* Find if a postcondition contains [\result] *)
class postconditions_mention_result = object
  inherit Visitor.frama_c_inplace

  method! vterm_lhost = function
    | TResult _ -> raise Exit
    | _ -> Cil.DoChildren
end
let postconditions_mention_result spec =
  let vis = new postconditions_mention_result in
  let aux_bhv bhv =
    let aux (_, post) = ignore (Visitor.visitFramacIdPredicate vis post) in
    List.iter aux bhv.b_post_cond
  in
  try
    List.iter aux_bhv spec.spec_behavior;
    false
  with Exit -> true

let conv_relation rel =
  let module C = Abstract_interp.Comp in
  match rel with
  | Req -> C.Eq
  | Rneq -> C.Ne
  | Rle -> C.Le
  | Rlt -> C.Lt
  | Rge -> C.Ge
  | Rgt -> C.Gt

module PairExpBool =
  Datatype.Pair_with_collections(Cil_datatype.Exp)(Datatype.Bool)

module MemoLvalToExp =
  Cil_state_builder.Lval_hashtbl
    (Cil_datatype.Exp)
    (struct
      let name = "Eva_utils.MemoLvalToExp"
      let size = 64
      let dependencies = [ Ast.self ]
    end)

let lval_to_exp =
  MemoLvalToExp.memo
    (fun lv -> Cil.new_exp ~loc:Cil_datatype.Location.unknown (Lval lv))

let rec height_expr expr =
  match expr.enode with
  | Const _ | SizeOf _ | SizeOfStr _ | AlignOf _ -> 0
  | Lval lv | AddrOf lv | StartOf lv  -> height_lval lv + 1
  | UnOp (_,e,_) | CastE (_, e) | SizeOfE e | AlignOfE e
    -> height_expr e + 1
  | BinOp (_,e1,e2,_) -> max (height_expr e1) (height_expr e2) + 1

and height_lval (host, offset) =
  let h1 = match host with
    | Var _ -> 0
    | Mem e -> height_expr e + 1
  in
  max h1 (height_offset offset) + 1

and height_offset = function
  | NoOffset  -> 0
  | Field (_,r) -> height_offset r + 1
  | Index (e,r) -> max (height_expr e) (height_offset r) + 1


let skip_specifications kf =
  Parameters.SkipLibcSpecs.get () &&
  Kernel_function.is_definition kf &&
  Cil.is_in_libc (Kernel_function.get_vi kf).vattr
