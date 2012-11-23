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
open Cil
open Cil_datatype

let named_predicate_to_exp_ref
    : (kernel_function -> Env.t -> predicate named -> exp * Env.t) ref
    = Extlib.mk_fun "named_predicate_to_exp_ref"

let term_to_exp_ref
    : (Env.t -> typ option -> term -> exp * Env.t) ref
    = Extlib.mk_fun "term_to_exp_ref"

let rte_to_exp_ref
    : (kernel_function -> Env.t -> exp -> Env.t) ref
    = Extlib.mk_fun "rte_to_exp_ref"

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
	    | Ltype _ as ty when Logic_const.is_boolean_type ty -> v, tl
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

let () = Typing.compute_quantif_guards_ref := compute_quantif_guards

module Label_ids = 
  State_builder.Counter(struct let name = "E_ACSL.Label_ids" end)

let convert kf env loc is_forall p bounded_vars hyps goal =
  (* part depending on the kind of quantifications 
     (either universal or existential) *)
  let init_val, found_val, mk_guard = 
    let z = zero ~loc in
    let o = one ~loc in
    if is_forall then o, z, (fun x -> x) 
    else z, o, (fun e -> new_exp ~loc:e.eloc (UnOp(LNot, e, intType)))
  in
  let named_predicate_to_exp = !named_predicate_to_exp_ref in
  let term_to_exp = !term_to_exp_ref in
  (* universal quantification over integers (or a subtype of integer) *)
  let guards = compute_quantif_guards p bounded_vars hyps in
  let var_res, res, env =
    (* variable storing the result of the quantifier *)
    let name = if is_forall then "forall" else "exists" in
    Env.new_var
      ~loc
      ~name
      env
      None
      intType
      (fun v _ ->
	let lv = var v in
	[ mkStmtOneInstr ~valid_sid:true (Set(lv, init_val, loc)) ])
  in
  let end_loop_ref = ref dummyStmt in
  let rec mk_for_loop env = function
    | [] -> 
      (* innermost loop body: store the result in [res] and go out according
	 to evaluation of the goal *)
      let test, env = named_predicate_to_exp kf (Env.push env) goal in
      let env = !rte_to_exp_ref kf env test in
      let then_block = mkBlock [ mkEmptyStmt ~loc () ] in
      let else_block = 
	(* use a 'goto', not a simple 'break' in order to handle 'forall' with
	   multiple binders (leading to imbricated loops) *)
	mkBlock
	  [ mkStmtOneInstr
	       ~valid_sid:true (Set(var var_res, found_val, loc));
	    mkStmt ~valid_sid:true (Goto(end_loop_ref, loc)) ]
      in
      let blk, env = 
	Env.pop_and_get
	  env
	  (mkStmt ~valid_sid:true
	     (If(mk_guard test, then_block, else_block, loc)))
	  ~global_clear:false
	  Env.After
      in
      (* TODO: could be optimised if [pop_and_get] would return a list of
	 stmts *)
      [ mkStmt ~valid_sid:true (Block blk) ], env
    | (t1, rel1, logic_x, rel2, t2) :: tl ->
      let t_plus_one t =
	Logic_const.term ~loc
	  (TBinOp(PlusA, t, Logic_const.tinteger ~loc 1))
	  Linteger
      in
      let t1 = match rel1 with
	| Rlt -> 
	  let t = t_plus_one t1 in
	  Typing.type_term t;
	  t
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
      let t2_one = t_plus_one t2 in
      Typing.type_term t2_one;
      let ty = Typing.principal_type t1 t2_one in
      (* loop counter corresponding to the quantified variable *)
      logic_x.lv_type <- if Mpz.is_t ty then Linteger else Ctype ty;
      let var_x, x, env = Env.Logic_binding.add env logic_x in
      let lv_x = var var_x in
      let env = 
	if Mpz.is_t ty then Env.add_stmt env (Mpz.init ~loc x) else env 
      in
      (* build the inner loops and loop body *)
      let body, env = mk_for_loop env tl in
      (* initialize the loop counter to [t1] *)
      let e1, env = term_to_exp (Env.push env) (Some ty) t1 in
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
      let guard = Logic_const.term (TBinOp(bop2, tlv, t2)) Linteger in
      Typing.type_term guard;
      let guard_exp, env = term_to_exp (Env.push env) (Some intType) guard in
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
      let tlv_one = t_plus_one tlv in
      (* previous typing ensures that [x++] fits type [ty] *)
      Typing.unsafe_set_term tlv_one ty;
      let incr, env = term_to_exp (Env.push env) (Some ty) tlv_one in
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

let quantif_to_exp kf env p = 
  let loc = p.loc in
  match p.content with
  | Pforall(bounded_vars, { content = Pimplies(hyps, goal) }) -> 
    convert kf env loc true p bounded_vars hyps goal
  | Pforall _ -> Error.not_yet "unguarded \\forall quantification"
  | Pexists(bounded_vars, { content = Pand(hyps, goal) }) -> 
    convert kf env loc false p bounded_vars hyps goal
  | Pexists _ -> Error.not_yet "unguarded \\exists quantification"
  | _ -> assert false

(*
Local Variables:
compile-command: "make"
End:
*)
