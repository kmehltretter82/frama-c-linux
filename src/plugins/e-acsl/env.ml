(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2010                                               *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
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
  new_exps: exp Term.Map.t; (* generated mpz variables as exp from terms *)
  clear_stmts: stmt list; (* stmts freeing the memory before exiting the 
			     block *) 
}

type block_info = {
  new_block_vars: varinfo list; (* generated variables local to the block *)
  new_stmts: stmt list; (* generated stmts to put at the beginning of the 
			   block *) 
}

type local_env = { block_info: block_info; mpz_tbl: mpz_tbl }

type t = 
    { visitor: Visitor.frama_c_visitor; 
      new_global_vars: varinfo list; (* generated variables at function 
					level *)
      global_mpz_tbl: mpz_tbl;
      env_stack: local_env list;
      cpt: int; (* counter used when generating variables *) }

let empty_block = 
  { new_block_vars = [];
    new_stmts = [] }

let empty_mpz_tbl =
  { new_exps = Term.Map.empty;
    clear_stmts = [] }

let dummy = 
  { visitor = 
      new Visitor.generic_frama_c_visitor 
	Project_skeleton.dummy
	(inplace_visit ()); 
    new_global_vars = [];
    global_mpz_tbl = empty_mpz_tbl; 
    env_stack = []; 
    cpt = 0 }

let empty v = 
  { visitor = v; 
    new_global_vars = [];
    global_mpz_tbl = empty_mpz_tbl; 
    env_stack = []; 
    cpt = 0 }

let top env = match env.env_stack with [] -> assert false | hd :: tl -> hd, tl

(* eta-expansion required for typing generalisation *)
let acc_list_rev acc l = List.fold_left (fun acc x -> x :: acc) acc l

let do_new_var ?(global=false) env t ty mk_stmts =
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
      ("e_acsl_" ^ string_of_int n)
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
  let new_block = { new_block_vars = new_block_vars; new_stmts = new_stmts } in
  e, 
  if is_t then 
    let extend_tbl tbl = 
(*      Options.feedback "memoizing %a for term %a" 
	Varinfo.pretty v (fun fmt t -> match t with None -> Format.fprintf fmt
	  "NONE" | Some t -> Term.pretty fmt t) t;*)
      { clear_stmts = Mpz.clear e :: tbl.clear_stmts;
	new_exps = match t with
	| None -> tbl.new_exps
	| Some t -> Term.Map.add t e tbl.new_exps }
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

let new_var ?(global=false) env t ty mk_stmts = 
  let local_env, _ = top env in
  if global then
    (* do not use memoisation here: it is incorrect for terms corresponding to
       impure expressions *)
    do_new_var ~global env t ty mk_stmts  
  else
    try
      match t with
      | None -> raise No_term
      | Some t -> Term.Map.find t local_env.mpz_tbl.new_exps, env
    with Not_found | No_term -> 
      do_new_var ~global env t ty mk_stmts  

let new_var_and_mpz_init ?global env t mk_stmts = 
  new_var ?global env t Mpz.t (fun v e -> Mpz.init e :: mk_stmts v e)

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

let push env = 
  (*  Options.feedback "push";*)
  let local_env = { block_info = empty_block; mpz_tbl = empty_mpz_tbl } in
  { env with env_stack = local_env :: env.env_stack }

let pop env =
(*  Options.feedback "pop";*)
  let _, tl = top env in
  { env with env_stack = tl }

type where = Before | Middle | After
let pop_and_get env stmt ~global_clear where =
(*  Options.feedback "pop_and_get";*)
  let local_env, tl = top env in
  let clear = 
    if global_clear then 
      env.global_mpz_tbl.clear_stmts @ local_env.mpz_tbl.clear_stmts
    else
      local_env.mpz_tbl.clear_stmts
  in
(*  Options.feedback "clearing %d mpz (must_clear: %b)" 
    (List.length clear) must_clear;*)
  let block = local_env.block_info in
  let b = 
    let new_s = block.new_stmts in
    let stmts = match where with
      | Before -> stmt :: acc_list_rev (List.rev clear) new_s
      | Middle -> acc_list_rev (stmt :: List.rev clear) new_s
      | After -> acc_list_rev (acc_list_rev [ stmt ] clear) new_s
    in
    mkBlock stmts
  in
(*  List.iter (fun v -> Options.feedback "new_block_vars %a" Varinfo.pretty v)
    block.new_block_vars;*)
  b.blocals <- acc_list_rev b.blocals block.new_block_vars;
  b, { env with env_stack = tl }

let get_generated_variables env = List.rev env.new_global_vars

(*
Local Variables:
compile-command: "make"
End:
*)
