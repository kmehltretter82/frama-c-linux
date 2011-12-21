(**************************************************************************)
(*                                                                        *)
(*  This file is part of the E-ACSL plug-in of Frama-C.                   *)
(*                                                                        *)
(*  Copyright (C) 2011                                                    *)
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
open Cil
open Cil_datatype

let named_predicate_to_exp_ref
    : (Env.t -> predicate named -> exp * Env.t) ref
    = Extlib.mk_fun "named_predicate_to_exp_ref"

let term_to_exp_ref
    : (Env.t -> logic_type -> term -> exp * Env.t) ref
    = Extlib.mk_fun "term_to_exp_ref"

let compute_quantif_guards quantif bounded_vars hyps = 
  let error msg pp x =
    let msg1 = Pretty_utils.sfprintf msg pp x in
    let msg2 = 
      Pretty_utils.sfprintf "@[ in quantification@ %a@]"
	d_predicate_named quantif
    in
    Error.untypable (msg1 ^ msg2)
  in
  let rec aux acc vars p = 
    match p.content with
    | Pand({ content = Prel((Rlt | Rle) as r1, t11, t12) },
	   { content = Prel((Rlt | Rle) as r2, t21, t22) }) ->
      (match t12.term_node, t21.term_node with
      | TLval(TVar x1, TNoOffset), TLval(TVar x2, TNoOffset) -> 
	let v, vars = match vars with
	  | [] -> error "@[too much constraint(s)%a@]" (fun _ () -> ()) ()
	  | v :: tl -> 
	    match v.lv_type with
	    | Ctype ty when isIntegralType ty -> v, tl
	    | Linteger -> v, tl
	    | Ctype _ | Ltype _ | Lvar _ | Lreal | Larrow _ -> 
	      error "@[non integer variable %a@]" d_logic_var v
	in
	if Logic_var.equal x1 x2 && Logic_var.equal x1 v then
	  (t11, r1, x1, r2, t22) :: acc, vars
	else
	  error "@[invalid binder %a@]" d_term t21
      | TLval _, _ -> error "@[invalid binder %a@]" d_term t21
      | _, _ -> error "@[invalid binder %a@]" d_term t12)
    | Pand(p1, p2) -> 
      let acc, vars = aux acc vars p1 in
      aux acc vars p2
    | _ -> error "@[invalid guard %a@]" d_predicate_named p
  in 
  let acc, vars = aux [] bounded_vars hyps in
  (match vars with
  | [] -> ()
  | _ :: _ ->
    let msg = 
      Pretty_utils.sfprintf
	"@[unguarded variable%s %tin quantification@ %a@]" 
	(if List.length vars = 1 then "" else "s") 
	(fun fmt -> 
	  List.iter (fun v -> Format.fprintf fmt "@[%a @]" d_logic_var v) vars)
	d_predicate_named quantif
    in
    Error.untypable msg);
  List.rev acc

module Label_ids = 
  State_builder.Counter(struct let name = "E_ACSL.Label_ids" end)

let convert env loc p bounded_vars hyps goal =
  let named_predicate_to_exp = !named_predicate_to_exp_ref in
  let term_to_exp = !term_to_exp_ref in
  (* universal quantification over integers (or a subtype of integer) *)
  let guards = compute_quantif_guards p bounded_vars hyps in
  let env = List.fold_left Env.Logic_binding.add env bounded_vars in
  let var_res = ref Varinfo.dummy in
  let res, env =
    (* variable storing the result of the \forall *)
    Env.new_var env None intType
      (fun v _ ->
	var_res := v;
	let lv = var v in
	[ mkStmtOneInstr ~valid_sid:true (Set(lv, one ~loc, loc)) ])
  in
  let end_loop_ref = ref dummyStmt in
  let rec mk_for_loop env = function
    | [] -> 
      (* innermost loop body: store the result in [res] and go out according
	 to evaluation of the goal *)
      let test, env = named_predicate_to_exp (Env.push env) goal in
      let then_block = mkBlock [ mkEmptyStmt ~loc () ] in
      let else_block = 
	(* use a 'goto', not a simple 'break' in order to handle 'forall' with
	   multiple binders (leading to imbricated loops) *)
	mkBlock
	  [ mkStmtOneInstr
	      ~valid_sid:true (Set(var !var_res, zero ~loc, loc));
	    mkStmt ~valid_sid:true (Goto(end_loop_ref, loc)) ]
      in
      let blk, env = 
	Env.pop_and_get
	  env
	  (mkStmt ~valid_sid:true (If(test, then_block, else_block, loc)))
	  ~global_clear:false
	  Env.After
      in
      (* TODO: could be optimised if [pop_and_get] would return a list of
	 stmts *)
      [ mkStmt ~valid_sid:true (Block blk) ], env
    | (t1, rel1, logic_x, rel2, t2) :: tl ->
      let body, env = mk_for_loop env tl in
      let t_plus_one t =
	Logic_const.term ~loc
	  (TBinOp(PlusA, t, Logic_const.tinteger ~loc ~ikind:IChar 1))
	  Linteger
      in
      let t1 = match rel1 with
	| Rlt -> t_plus_one t1
	| Rle -> t1
	| Rgt | Rge | Req | Rneq -> assert false
      in
      let bop2 = match rel2 with
	| Rlt -> Lt
	| Rle -> Le
	| Rgt | Rge | Req | Rneq -> assert false
      in
      (* we increment the loop counter one more time (at the end of the
	 loop). Thus to prevent  overflow, check the type of [t2 + 1] instead
	 of [t2]. *) 
      let ty = Typing.principal_type_from_term t1 (t_plus_one t2) in
      let ty = Typing.principal_type ty logic_x.lv_type in
      (* loop counter corresponding to the quantified variable *)
      let var_x = Env.Logic_binding.get env logic_x in
      let lv_x = var var_x in
      let x = new_exp ~loc (Lval lv_x) in
      let env = match ty with
	| Ctype ty when isIntegralType ty -> 
	  var_x.vtype <- ty;
	  env
	| Linteger -> 
	  var_x.vtype <- Mpz.t;
	  Env.add_stmt env (Mpz.init x)
	| Ctype _ | Ltype _ | Lvar _ | Lreal | Larrow _ -> assert false
      in
      (* initialize the loop counter to [t1] *)
      let e1, env = term_to_exp (Env.push env) ty t1 in
      let init_blk, env = 
	Env.pop_and_get 
	  env
	  (Mpz.affect lv_x x e1)
	  ~global_clear:false
	  Env.Middle
      in
      (* generate the guard [x bop t2] *)
      let stmts_block b = [ mkStmt ~valid_sid:true (Block b) ] in
      let tlv = Logic_const.tvar ~loc (cvar_to_lvar var_x) in
      let guard_exp, env = 
	term_to_exp
	  (Env.push env)
	  (Ctype intType)
	  (Logic_const.term (TBinOp(bop2, tlv, t2)) ty)
      in
      let break_stmt = mkStmt ~valid_sid:true (Break guard_exp.eloc) in
      let guard_blk, env =
	Env.pop_and_get
	  env
	  (mkStmt ~valid_sid:true
	     (If(guard_exp,
		 mkBlock [ mkEmptyStmt () ],
		 mkBlock [ break_stmt ], 
		 guard_exp.eloc)))
	  ~global_clear:false
	  Env.Middle
      in
      let guard = stmts_block guard_blk in
      (* increment the loop counter [x++] *)
      let incr, env = term_to_exp (Env.push env) ty (t_plus_one tlv) in
      let next_blk, env = 
	Env.pop_and_get
	  env
	  (Mpz.affect lv_x x incr)
	  ~global_clear:false
	  Env.Middle
      in
      (* generate the whole loop *)
      let start = stmts_block init_blk in
      let next = stmts_block next_blk in
      start @
	[ mkStmt ~valid_sid:true
	    (Loop ([],
		   mkBlock (guard @ body @ next),
		   loc, 
		   None, 
		   Some break_stmt)) ], 
      env
  in
  let stmts, env = mk_for_loop env guards in
  let env = 
    Env.add_stmt env (mkStmt ~valid_sid:true (Block (mkBlock stmts))) 
  in
  (* where to jump to go out of the loop *)
  let end_loop = mkEmptyStmt ~loc () in
  let label_name = "e_acsl_end_loop" ^ string_of_int (Label_ids.next ()) in
  let label = Label(label_name, loc, false) in
  end_loop.labels <- label :: end_loop.labels;
  end_loop_ref := end_loop;
  let env = Env.add_stmt env end_loop in
  let env = List.fold_left Env.Logic_binding.remove env bounded_vars in
  res, env

(*
Local Variables:
compile-command: "make"
End:
*)
