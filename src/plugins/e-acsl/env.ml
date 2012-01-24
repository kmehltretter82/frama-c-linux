(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012                                                    *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype
open Cil

let global_state = ref State.dummy

type mpz_tbl = {   
  new_exps: (varinfo * exp) Term.Map.t; (* generated mpz variables as exp from
					   terms *)
  clear_stmts: stmt list; (* stmts freeing the memory before exiting the 
			     block *) 
}

type block_info = {
  new_block_vars: varinfo list; (* generated variables local to the block *)
  new_stmts: stmt list; (* generated stmts to put at the beginning of the 
			   block *) 
  pre_stmts: stmt list; (* stmts already inserted into the current stmt, but
			   which should be before [new_stmts]. *)
}

type local_env = { block_info: block_info; mpz_tbl: mpz_tbl }

type t = 
    { visitor: Visitor.frama_c_visitor; 
      annotation_kind: Misc.annotation_kind;
      new_global_vars: varinfo list; (* generated variables at function level *)
      global_mpz_tbl: mpz_tbl;
      env_stack: local_env list;
      var_mapping: Varinfo.t Logic_var.Map.t; (* bind logic var to C var *)
      cpt: int; (* counter used when generating variables *) }

module Varname: sig 
  val get: string -> string 
  val clear: unit -> unit
end = struct

  module H = Datatype.String.Hashtbl
  let tbl = H.create 7

  let get s = 
    let _, u = Extlib.make_unique_name (H.mem tbl) ~sep:"_" s in
    H.add tbl u ();
    u

  let clear () = H.clear tbl

end

let empty_block = 
  { new_block_vars = [];
    new_stmts = [];
    pre_stmts = [] }

let empty_mpz_tbl =
  { new_exps = Term.Map.empty;
    clear_stmts = [] }

let dummy = 
  { visitor = 
      new Visitor.generic_frama_c_visitor 
	Project_skeleton.dummy
	(inplace_visit ()); 
    annotation_kind = Misc.Assertion;
    new_global_vars = [];
    global_mpz_tbl = empty_mpz_tbl; 
    env_stack = []; 
    var_mapping = Logic_var.Map.empty;
    cpt = 0 }

let empty v =
  { visitor = v; 
    annotation_kind = Misc.Assertion;
    new_global_vars = [];
    global_mpz_tbl = empty_mpz_tbl; 
    env_stack = []; 
    var_mapping = Logic_var.Map.empty;
    cpt = 0 }

let top env = match env.env_stack with [] -> assert false | hd :: tl -> hd, tl

(* eta-expansion required for typing generalisation *)
let acc_list_rev acc l = List.fold_left (fun acc x -> x :: acc) acc l

let do_new_var ?(global=false) ?(name="") env t ty mk_stmts =
  let local_env, tl_env = top env in
  let local_block = local_env.block_info in
  let is_t = Mpz.is_t ty in
  if is_t then Mpz.is_now_referenced ();
  let n = succ env.cpt in
  let v =
    makeVarinfo
      ~logic:false
      ~generated:true
      false (* is a global? *)
      false (* is a formal? *)
      (Varname.get ("__e_acsl" ^ if name = "" then "" else "_" ^ name))
      ty
  in
(*  Options.feedback "new variable %a (global? %b)" Varinfo.pretty v global;*)
  let e = Misc.new_lval v in
  let stmts = mk_stmts v e in
  let new_stmts = acc_list_rev local_block.new_stmts stmts in
  let new_block_vars = 
    if global then local_block.new_block_vars 
    else v :: local_block.new_block_vars
  in
  let new_block = 
    { new_block_vars = new_block_vars; 
      new_stmts = new_stmts;
      pre_stmts = local_block.pre_stmts } 
  in
  v,
  e, 
  if is_t then 
    let extend_tbl tbl = 
(*      Options.feedback "memoizing %a for term %a" 
	Varinfo.pretty v (fun fmt t -> match t with None -> Format.fprintf fmt
	  "NONE" | Some t -> Term.pretty fmt t) t;*)
      { clear_stmts = Mpz.clear e :: tbl.clear_stmts;
	new_exps = match t with
	| None -> tbl.new_exps
	| Some t -> Term.Map.add t (v, e) tbl.new_exps }
    in
    if global then
      let local_env = { local_env with block_info = new_block } in
      (* also memoise the new variable, but must never be used *)
      { env with
	cpt = n;
	new_global_vars = v :: env.new_global_vars;
	global_mpz_tbl = extend_tbl env.global_mpz_tbl;
	env_stack = local_env :: tl_env }
    else
      let local_env = 
	{ block_info = new_block; mpz_tbl = extend_tbl local_env.mpz_tbl } 
      in
      { env with cpt = n; env_stack = local_env :: tl_env }
  else
    let new_global_vars = 
      if global then v :: env.new_global_vars
      else env.new_global_vars
    in
    { env with
      new_global_vars = new_global_vars;
      cpt = n;
      env_stack = { local_env with block_info = new_block } :: tl_env }

exception No_term

let new_var ?(global=false) ?name env t ty mk_stmts = 
  let local_env, _ = top env in
  if global then
    (* do not use memoisation here: it is incorrect for terms corresponding to
       impure expressions
       [JS 2011/11/23] actually it is correct now since globals are only use for
       \at *)
    do_new_var ~global ?name env t ty mk_stmts  
  else
    try
      match t with
      | None -> raise No_term
      | Some t -> 
	let v, e = Term.Map.find t local_env.mpz_tbl.new_exps in
	if Typ.equal ty v.vtype then v, e, env else raise No_term
    with Not_found | No_term -> 
      do_new_var ~global ?name env t ty mk_stmts  

let new_var_and_mpz_init ?global ?name env t mk_stmts = 
  new_var ?global ?name env t Mpz.t (fun v e -> Mpz.init e :: mk_stmts v e)

module Logic_binding = struct

  let add env logic_v =
    let ty = match logic_v.lv_type with
      | Ctype ty -> ty
      | Linteger -> Mpz.t
      | Ltype _ as ty when Logic_const.is_boolean_type ty -> charType
      | Ltype _ | Lvar _ | Lreal | Larrow _ as lty -> 
	let msg = 
	  Pretty_utils.sfprintf 
	    "logic variable of type %a" Logic_type.pretty lty
	in
	Error.not_yet msg
    in
    let v, e, env = new_var env ~name:logic_v.lv_name None ty (fun _ _ -> []) in
    v,
    e, 
    { env with var_mapping = Logic_var.Map.add logic_v v env.var_mapping }

  let get env logic_v = 
    try Logic_var.Map.find logic_v env.var_mapping
    with Not_found -> assert false

  let remove env v = 
    let map = env.var_mapping in
    assert (Logic_var.Map.mem v map);
    { env with var_mapping = Logic_var.Map.remove v map }

end

let current_kf env = 
  let v = env.visitor in
  match v#current_kf with
  | None -> None
  | Some kf -> Some (Cil.get_kernel_function v#behavior kf)

let get_visitor env = env.visitor

let add_assert env stmt annot = 
  match current_kf env with
  | None -> assert false (* TODO: ??? *)
  | Some kf ->
    Queue.add
      (fun () -> Annotations.add_assert kf stmt [ !global_state ] annot) 
      env.visitor#get_filling_actions

let add_stmt env stmt =
  let local_env, tl = top env in
  let block = local_env.block_info in
  let block = { block with new_stmts = stmt :: block.new_stmts } in
  { env with env_stack = { local_env with block_info = block } :: tl }

let extend_stmt_in_place env stmt ~pre block =
  let new_stmt = mkStmt ~valid_sid:true (Block block) in
  let sk = stmt.skind in
  stmt.skind <- Block (mkBlock [ new_stmt; mkStmt ~valid_sid:true sk ]);
  if pre then 
    let local_env, tl_env = top env in
    let b_info = local_env.block_info in
    let b_info = { b_info with pre_stmts = new_stmt :: b_info.pre_stmts } in
    { env with env_stack = { local_env with block_info = b_info } :: tl_env }
  else
    env

let push env = 
(*  Options.feedback "push (was %d)" (List.length env.env_stack);*)
  let local_env = { block_info = empty_block; mpz_tbl = empty_mpz_tbl } in
  { env with env_stack = local_env :: env.env_stack }

let pop env =
(*  Options.feedback "pop";*)
  let _, tl = top env in
  { env with env_stack = tl }

type where = Before | Middle | After
let pop_and_get env stmt ~global_clear where =
  (*  Options.feedback "pop_and_get (%d)" (List.length env.env_stack); *)
  let local_env, tl = top env in
  let clear = 
    if global_clear then begin
      Varname.clear ();
      env.global_mpz_tbl.clear_stmts @ local_env.mpz_tbl.clear_stmts
    end else
      local_env.mpz_tbl.clear_stmts
  in
(*  Options.feedback "clearing %d mpz (must_clear: %b)" 
    (List.length clear) must_clear;*)
  let block = local_env.block_info in
  let b = 
    let pre_stmts, stmt = 
      let rec extract stmt acc = function
	| [] -> acc, stmt
	| _ :: tl ->
	  match stmt.skind with
	  | Block { bstmts = [ fst; snd ] } ->
	    (* [JS 2011/11/23] stmts look the same as expected; but sid are
	       different and I don't know why ==> thus the assertion does not
	       hold :-( *)
(*	    assert (Stmt.equal stmt' fst);*)
	    extract snd (fst :: acc) tl
	  | _ -> assert false
      in
      extract stmt [] block.pre_stmts
    in
    let new_s = block.new_stmts in
    let stmts = match where with
      | Before -> stmt :: acc_list_rev (List.rev clear) new_s
      | Middle -> acc_list_rev (stmt :: List.rev clear) new_s
      | After -> acc_list_rev (acc_list_rev [ stmt ] clear) new_s
    in
    mkBlock (acc_list_rev stmts pre_stmts)
  in
  b.blocals <- acc_list_rev b.blocals block.new_block_vars;
  b, { env with env_stack = tl }

let get_generated_variables env = List.rev env.new_global_vars

let stmt_of_label env = function
  | StmtLabel { contents = stmt } -> stmt
  | LogicLabel(_, label) when label = "Here" -> 
    (match env.visitor#current_stmt with
    | None -> Error.not_yet "label \"Here\" in function contract"
    | Some s -> s)
  | LogicLabel(_, label) when label = "Old" || label = "Pre" -> 
    (try Kernel_function.find_first_stmt (Extlib.the env.visitor#current_kf)
     with Kernel_function.No_Statement -> assert false)
  | LogicLabel(_, label) when label = "Post" -> 
    (try Kernel_function.find_return (Extlib.the env.visitor#current_kf)
     with Kernel_function.No_Statement -> assert false)
  | LogicLabel(_, _label) -> assert false

let annotation_kind env = env.annotation_kind
let set_annotation_kind env k = { env with annotation_kind = k }

(*
Local Variables:
compile-command: "make"
End:
*)
