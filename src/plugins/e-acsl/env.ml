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

let self = ref State.dummy

let queue = ref (Queue.create ())
let register_actions_queue q = queue := q

type t = 
    { var_cpt: int; (* counter used for generating variables in a function *)
      fct_vars: Varinfo.Set.t; (* generated variables local to a function.
				  Use a set to prevent to add twice a variable
				  when merging. *)
      block_vars: varinfo list; (* generated variables local to a block.
				   Subset of field [vars] *)
      beginning_of_block: stmt list; (* list of stmts to be inserted before the
					visiting node *)
      end_of_block: stmt list (* list of stmts to be inserted after the visiting
				 node *) }
      
let empty = 
  { var_cpt = 0; 
    fct_vars = Varinfo.Set.empty; 
    block_vars = [];
    beginning_of_block = []; 
    end_of_block = [] }

let no_overlap ~from env = 
  { env with var_cpt = Extlib.max_cpt from.var_cpt env.var_cpt }

let merge_function_vars ~from env = 
  { env with 
    var_cpt = from.var_cpt; 
    fct_vars = Varinfo.Set.union env.fct_vars from.fct_vars }

let merge_block_vars ~from env =
  let env = merge_function_vars ~from env in
  { env with block_vars = env.block_vars @ from.block_vars }

let is_empty_block env = 
  if env.beginning_of_block = [] then begin
    assert (env.end_of_block = [] && env.block_vars = []);
    true
  end else
    false      

let is_empty env = env.var_cpt = 0 && is_empty_block env 

let add_stmt env s = 
  { env with beginning_of_block = s :: env.beginning_of_block }

let add_assert s p = 
  Queue.add
    (fun () -> 
      (* Don't work since the kernel_function does not yet exist in the new
	 project. Virgile said he was implementing the missing stuff in the
	 visitor. Wait and see... *)
      let kf = Kernel_function.find_englobing_kf s in
      Annotations.add_assert kf s [ !self ] p) 
    !queue

let new_var env ty mk_stmts = 
  let is_t = Mpz.is_t ty in
  if is_t then Mpz.is_now_referenced ();
  let n = succ env.var_cpt in
  let v =
    makeVarinfo
      ~logic:false
      ~generated:true
      false (* is a global? *)
      false (* is a formal? *)
      ("e_acsl_" ^ string_of_int n)
      ty
  in
  let e = Misc.new_lval v in
  let stmts = mk_stmts v e in
  e,
  { var_cpt = n;
    fct_vars = Varinfo.Set.add v env.fct_vars;
    block_vars = v :: env.block_vars;
    beginning_of_block = 
      List.fold_left (fun l s -> s :: l) env.beginning_of_block stmts;
    end_of_block = 
      if is_t then Mpz.clear e :: env.end_of_block else env.end_of_block }

let new_var_and_mpz_init env mk_stmts = 
  new_var env Mpz.t (fun v e -> Mpz.init e :: mk_stmts v e)

let generated_function_variables env = 
  List.sort
    (fun v1 v2 -> String.compare v1.vname v2.vname)
    (Varinfo.Set.elements env.fct_vars)

let generated_block_variables env = List.rev env.block_vars

let block env s = 
  let b = 
    mkBlock 
      (List.rev env.beginning_of_block @ [ s ] @ List.rev env.end_of_block)
  in
  b.blocals <- b.blocals @ List.rev env.block_vars;
  b

let block_as_stmt env s = 
  if is_empty_block env then s else mkStmt ~valid_sid:true (Block (block env s))

let block_option env s = 
  if is_empty_block env then None else Some (block env s)

let close_block_option env = 
  block_option env (mkStmt ~valid_sid:true (Instr (Skip Location.unknown)))

let pretty fmt env =
  Format.fprintf fmt "CPT = %d@\n" env.var_cpt;
  Format.fprintf fmt "FCT_VARS = %t@\n"
    (fun fmt ->
      Varinfo.Set.iter (fun v -> Format.fprintf fmt "v%d " v.vid) env.fct_vars);
  Format.fprintf fmt "BLOCK_VARS = %t@\n"
    (fun fmt -> 
      List.iter (fun v -> Format.fprintf fmt "v%d " v.vid) env.block_vars);
  Format.fprintf fmt "BEGIN BLOCK = %t@\n" 
    (fun fmt -> 
      List.iter
	(fun s -> Format.fprintf fmt "%a@\n" d_stmt s) 
	env.beginning_of_block);
  Format.fprintf fmt "EBD BLOCK = %t@." 
    (fun fmt -> 
      List.iter
	(fun s -> Format.fprintf fmt "%a@\n" d_stmt s) 
	env.end_of_block)

(*
Local Variables:
compile-command: "make"
End:
*)
